require "json"
require "uuid"

module MoanaTypes
  class VolumeException < Exception
  end

  struct BrickRequest
    include JSON::Serializable

    property node_id : String,
             path : String,
             device : String,
             port : Int32 = 0,
             node_hostname = "",
             node_endpoint = ""
  end

  struct VolumeCreateRequest
    include JSON::Serializable

    property name : String,
             replica_count : Int32 = 1,
             disperse_count : Int32 = 1,
             bricks : Array(BrickRequest),
             brick_fs : String = "",
             fs_opts : String = "",
             start : Bool = true

    def find_free_port(node_id)
      # TODO: Also check from tasks table

      bricks = MoanaDB.list_bricks_by_node(node_id)

      used_ports = bricks.map do |brick|
        brick.port
      end

      (49252..49452).to_a.find do |port|
        !used_ports.includes?(port)
      end
    end

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
end
