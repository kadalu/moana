require "json"

module MoanaTypes
  class ErrorResponse
    include JSON::Serializable

    property error : String, status_code : Int32 = 0
  end

  class VolfileResponse
    include JSON::Serializable

    property content : String
  end

  class TaskResponse
    include JSON::Serializable

    property id, data, state, type, response, node : NodeResponse?

    def initialize(@id = "", @data = "", @state = "", @type = "", @response = "")
    end
  end

  class NodeResponse
    include JSON::Serializable

    property id, hostname, endpoint

    def initialize(@id = "", @hostname = "", @endpoint = "")
    end
  end

  class BrickResponse
    include JSON::Serializable

    property id, path, device, mount_path, node, port, state, type

    def initialize(@id = "",
                   @path = "",
                   @device = "",
                   @mount_path = "",
                   @port : Int32 = 0,
                   @state = "",
                   @type = "",
                   @node = NodeResponse.new)
    end
  end

  class SubvolResponse
    include JSON::Serializable

    property replica_count, disperse_count, type, bricks

    def initialize(@replica_count : Int32 = 1,
                   @disperse_count : Int32 = 1,
                   @type = "",
                   @bricks = [] of BrickResponse)
    end
  end

  class ClusterResponse
    include JSON::Serializable

    property id, name, nodes : Array(NodeResponse)?

    def initialize(@id = "", @name = "")
    end
  end

  class VolumeResponse
    include JSON::Serializable

    property id, name, replica_count, disperse_count, state, type, cluster, subvols, options

    def initialize(@id = "",
                   @name = "",
                   @replica_count : Int32 = 1,
                   @disperse_count : Int32 = 1,
                   @state = "",
                   @type = "",
                   @cluster = ClusterResponse.new,
                   @subvols = [] of SubvolResponse,
                                    @options = {} of String => String)
    end
  end
end
