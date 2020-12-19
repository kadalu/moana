require "json"
require "uuid"

module MoanaTypes
  class NodeRequest
    include JSON::Serializable

    property id, hostname, endpoint

    def initialize(@id : String = "", @hostname : String = "", @endpoint : String = "")
    end
  end

  class BrickRequest
    include JSON::Serializable

    property node_id : String|Nil,
             path : String,
             device : String,
             mount_path : String,
             port : Int32?,
             node : NodeRequest

    def initialize(@node_id = "", @path = "", @device = "", @mount_path = "", @node = NodeRequest.new)
    end
  end

  class VolumeRequest
    include JSON::Serializable

    property id, name, brick_fs, bricks, xfs_opts, zfs_opts, ext4_opts, replica_count, disperse_count, start, cluster_id : String?, type, options

    # Generate Volume ID server side
    def initialize(@id : String = UUID.random.to_s, @name = "", @brick_fs = "dir", @bricks = [] of BrickRequest, @xfs_opts = "", @zfs_opts = "", @ext4_opts = "", @replica_count = 1, @disperse_count = 1, @start = false, @type = "Distribute", @options="{}")
    end
  end
end
