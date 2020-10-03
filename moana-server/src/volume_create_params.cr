require "moana_types"

require "./models/node"

include MoanaTypes

class VolumeCreateParams
  @error = ""
  @valid = true
  @nodes = [] of Node

  property volume

  def initialize(params)
    @volume = VolumeRequest.from_json(params.to_unsafe_h["_json"])
    @volume.cluster_id = params["cluster_id"]
  end

  def seterror(msg)
    @error = msg
    @valid = false
  end

  def error
    @error
  end

  def first_node
    @nodes[0]
  end

  def cluster
    @cluster
  end

  def find_free_port(node_id)
    # TODO: Also check from tasks table

    bricks = Brick.where(node_id: node_id).select

    used_ports = bricks.map do |brick|
      brick.port
    end

    (49252..49452).to_a.find do |port|
      !used_ports.includes?(port)
    end
  end

  def validate_nodes
    return unless @valid

    @volume.bricks.each do |brick|
      if node = Node.find brick.node_id
        if node.cluster_id != @volume.cluster_id
          seterror "Node #{node.id} belongs to different Cluster"
          return
        end

        if port = find_free_port(node.id)
          brick.port = port
        else
          path_or_dev = brick.path == "" ? brick.device : brick.path
          seterror "Port not available for #{node.hostname}:#{path_or_dev}"
        end

        if node_id = node.id
          brick.node = NodeRequest.new node_id, node.hostname, node.endpoint
          brick.node_id = nil
        end
        @nodes << node
      else
        seterror "invalid Node #{brick.node_id}"
        return
      end
    end

    return ""
  end

  def validate_name
    return unless @valid

    if (/^[[:alpha:]][[:alnum:]]+$/ =~ @volume.name).nil?
      seterror "Invalid Volume name"
    end
  end

  def validate_brickfs
    return unless @valid

    if !["zfs", "xfs", "ext4", "dir"].includes?(@volume.brick_fs)
      seterror "Unsupported Brick FS"
    end
  end

  def validate_replica_count
    return unless @valid

    if @volume.replica_count > 1 && @volume.bricks.size % @volume.replica_count != 0
      seterror "Bricks count not matching with replica count"
    end
  end

  def validate_disperse_count
    return unless @valid

    if @volume.disperse_count > 1 && @volume.bricks.size % @volume.disperse_count != 0
      seterror "Bricks count not matching with disperse count"
    end
  end

  def validate_brick_device_or_path
    return unless @valid

    @volume.bricks.each do |brick|
      if @volume.brick_fs == "dir" && brick.path == ""
        seterror "Brick path not specified"
        return
      end

      if @volume.brick_fs != "dir" && brick.device == ""
        seterror "Brick path not specified"
        return
      end
    end
  end

  def volume_type
    if @volume.replica_count > 1
      if @volume.bricks.size > @volume.replica_count
        "distributed replicate"
      else
        "replicate"
      end
    elsif @volume.disperse_count > 1
      if @volume.bricks.size > @volume.disperse_count
        "distributed disperse"
      else
        "disperse"
      end
    else
      "distribute"
    end
  end

  def valid?
    # Volume name validations
    validate_name

    # Brick FS type validations
    validate_brickfs

    # Replica count and Brick count validations
    validate_replica_count

    # Disperse count and Brick count validations
    validate_disperse_count

    # Brick device is required when brick_fs is non dir,
    # else brick path is required
    validate_brick_device_or_path

    # Valid node ID exists and part of same Cluster
    # Also validate the Port available for a brick or not
    validate_nodes

    @volume.type = volume_type

    # TODO: Replica Bricks in a subvol are in same node [Best Practice]
    # TODO: Disperse Bricks in a subvol are in same node [Best Practice]
    # TODO: Brick Path validation [Best Practice](If `skip_path_validations=false`)
    # TODO: [Db] Volume name already exists in Volumes table(for same Cluster)
    # TODO: [Db] Volume name already exists in in-progress tasks table(for same Cluster)
    # TODO: [Db] Brick Path is not part of other bricks in same node
    # TODO: [Db] Brick device is not part of other bricks in same node

    @valid
  end
end
