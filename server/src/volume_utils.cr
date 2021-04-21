require "uuid"

require "moana_types"

DISTRIBUTE = "Distribute"
REPLICATE = "Replicate"
DISPERSE = "Disperse"
DISTRIBUTED_REPLICATE = "Distribute Replicate"
DISTRIBUTED_DISPERSE = "Distribute Disperse"

def update_node_details(volume, nodes)
  data = Hash(String, MoanaTypes::Node).new
  nodes.each do |node|
    data[node.id] = node
  end

  volume.subvols = volume.subvols.map do |subvol|
    subvol.bricks = subvol.bricks.map do |brick|
      brick.node.hostname = data[brick.node.id].hostname
      brick.node.endpoint = data[brick.node.id].endpoint

      brick
    end

    subvol
  end

  volume
end

def find_free_port(node_id)
  # Delete the Expired reserved ports
  MoanaDB.delete_expired_ports(node_id)

  # Reserved by in-progress tasks
  reserved_ports = MoanaDB.list_ports_by_node(node_id)

  # Used by Bricks
  used_ports = MoanaDB.list_brick_ports_by_node(node_id)

  # Search a Port which is not in used_ports or reserved_ports
  port = (49252..49452).to_a.find do |port|
    !used_ports.includes?(port) && !reserved_ports.includes?(port)
  end

  if !port.nil?
    # Reserve the Port for next 5 minutes
    MoanaDB.create_port(node_id, port)
  end

  port
end

struct MoanaTypes::VolumeCreateRequest
  def validate!(cluster_id)
    # Volume name validation
    if (/^[[:alpha:]][[:alnum:]]+$/ =~ @name).nil?
      raise VolumeException.new("Invalid Volume name")
    end

    # Brick FS validation
    if !["zfs", "xfs", "ext4", "dir"].includes?(@brick_fs)
      raise VolumeException.new("Unsupported Brick FS")
    end

    if @replica_count > 1 && @bricks.size % @replica_count != 0
      raise VolumeException.new("Bricks count not matching with replica count")
    end

    if @disperse_count > 1 && @bricks.size % @disperse_count != 0
      raise VolumeException.new("Bricks count not matching with disperse count")
    end

    @bricks.each do |brick|
      if @brick_fs == "dir" && brick.path == ""
        raise VolumeException.new("Brick path not specified")
      end

      if @brick_fs != "dir" && brick.device == ""
        raise VolumeException.new("Brick path not specified")
      end
    end

    @bricks = @bricks.map do |brick|
      if node = MoanaDB.get_node(brick.node_id)
        if node.cluster_id != cluster_id
          raise VolumeException.new("Node #{node.id} belongs to different Cluster")
        end

        if port = find_free_port(node.id)
          brick.port = port
        else
          path_or_dev = brick.path == "" ? brick.device : brick.path
          raise VolumeException.new("Port not available for #{node.hostname}:#{path_or_dev}")
        end

        brick.node_hostname = node.hostname
        brick.node_endpoint = node.endpoint
      else
        raise VolumeException.new("invalid Node #{brick.node_id}")
      end

      brick
    end

    # TODO: Replica Bricks in a subvol are in same node [Best Practice]
    # TODO: Disperse Bricks in a subvol are in same node [Best Practice]
    # TODO: Brick Path validation [Best Practice](If `skip_path_validations=false`)
    # TODO: [Db] Volume name already exists in Volumes table(for same Cluster)
    # TODO: [Db] Volume name already exists in in-progress tasks table(for same Cluster)
    # TODO: [Db] Brick Path is not part of other bricks in same node
    # TODO: [Db] Brick device is not part of other bricks in same node
  end
end

struct MoanaTypes::VolumeExpandRequest
  def validate!(volume, cluster_id)
    if volume.replica_count > 1 && @bricks.size % volume.replica_count != 0
      raise VolumeException.new("Bricks count not matching with replica count")
    end

    if volume.disperse_count > 1 && @bricks.size % volume.disperse_count != 0
      raise VolumeException.new("Bricks count not matching with disperse count")
    end

    @bricks.each do |brick|
      if volume.brick_fs == "dir" && brick.path == ""
        raise VolumeException.new("Brick path not specified")
      end

      if volume.brick_fs != "dir" && brick.device == ""
        raise VolumeException.new("Brick path not specified")
      end
    end

    @bricks = @bricks.map do |brick|
      if node = MoanaDB.get_node(brick.node_id)
        if node.cluster_id != cluster_id
          raise VolumeException.new("Node #{node.id} belongs to different Cluster")
        end

        if port = find_free_port(node.id)
          brick.port = port
        else
          path_or_dev = brick.path == "" ? brick.device : brick.path
          raise VolumeException.new("Port not available for #{node.hostname}:#{path_or_dev}")
        end

        brick.node_hostname = node.hostname
        brick.node_endpoint = node.endpoint
      else
        raise VolumeException.new("invalid Node #{brick.node_id}")
      end

      brick
    end

    # TODO: Replica Bricks in a subvol are in same node [Best Practice]
    # TODO: Disperse Bricks in a subvol are in same node [Best Practice]
    # TODO: Brick Path validation [Best Practice](If `skip_path_validations=false`)
    # TODO: [Db] Volume name already exists in Volumes table(for same Cluster)
    # TODO: [Db] Volume name already exists in in-progress tasks table(for same Cluster)
    # TODO: [Db] Brick Path is not part of other bricks in same node
    # TODO: [Db] Brick device is not part of other bricks in same node
  end
end

def volume_from_request(req : MoanaTypes::VolumeCreateRequest)
  volume = MoanaTypes::Volume.new
  volume.id = UUID.random.to_s
  volume.name = req.name
  volume.replica_count = req.replica_count
  volume.disperse_count = req.disperse_count
  volume.brick_fs = req.brick_fs
  volume.fs_opts = req.fs_opts

  subvol_type = DISTRIBUTE
  subvol_type = REPLICATE if req.replica_count > 1
  subvol_type = DISPERSE if req.disperse_count > 1

  subvol_bricks_count = req.bricks.size
  if req.replica_count > 1 || req.disperse_count > 1
    subvol_bricks_count = req.replica_count > 1 ? req.replica_count : req.disperse_count
  end
  number_of_subvols = req.bricks.size / subvol_bricks_count

  volume.type = subvol_type
  volume.type = "#{DISTRIBUTE} #{subvol_type}" if number_of_subvols > 1

  volume.subvols = (0 .. number_of_subvols-1).map do |sidx|
    subvol = MoanaTypes::Subvol.new

    subvol.replica_count = req.replica_count
    subvol.disperse_count = req.disperse_count
    subvol.type = subvol_type
    subvol.bricks = (0 .. subvol_bricks_count-1).map do |bidx|
      brickreq = req.bricks[sidx * subvol_bricks_count + bidx]
      brick = MoanaTypes::Brick.new
      brick.id = UUID.random.to_s
      brick.node.id = brickreq.node_id
      brick.path = brickreq.path
      brick.device = brickreq.device
      brick.port = brickreq.port

      brick
    end

    subvol
  end

  volume
end

def volume_from_request(volume : MoanaTypes::Volume, req : MoanaTypes::VolumeExpandRequest)
  subvol_bricks_count = volume.subvols[0].bricks.size
  number_of_new_subvols = req.bricks.size / subvol_bricks_count

  subvol_type = volume.subvols[0].type

  # Change Volume type if number of existing subvols was 1
  volume.type = "#{DISTRIBUTE} #{subvol_type}" if volume.subvols.size == 1

  (0 .. number_of_new_subvols - 1).each do |sidx|
    subvol = MoanaTypes::Subvol.new

    subvol.replica_count = volume.replica_count
    subvol.disperse_count = volume.disperse_count
    subvol.type = subvol_type
    subvol.bricks = (0 .. subvol_bricks_count-1).map do |bidx|
      brickreq = req.bricks[sidx * subvol_bricks_count + bidx]
      brick = MoanaTypes::Brick.new
      brick.id = UUID.random.to_s
      brick.node.id = brickreq.node_id
      brick.path = brickreq.path
      brick.device = brickreq.device
      brick.port = brickreq.port

      brick
    end

    volume.subvols << subvol
  end

  volume
end
