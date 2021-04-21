require "json"
require "uuid"

module MoanaTypes
  class VolumeException < Exception
  end

  struct NodeJoinRequest
    include JSON::Serializable

    property moana_url = "",
      cluster_id = "",
      hostname = "",
      endpoint = "",
      token = ""

    def initialize
    end
  end

  struct BrickRequest
    include JSON::Serializable

    property node_id = "",
      path = "",
      device = "",
      port : Int32 = 0,
      node_hostname = "",
      node_endpoint = ""

    def initialize
    end
  end

  struct VolumeCreateRequest
    include JSON::Serializable

    property name = "",
      replica_count : Int32 = 1,
      disperse_count : Int32 = 1,
      bricks = [] of MoanaTypes::BrickRequest,
      brick_fs = "",
      fs_opts = "",
      start = true,
      cluster_id = ""

    def initialize
    end
  end

  struct VolumeExpandRequest
    include JSON::Serializable

    property replica_count : Int32 = 1,
      disperse_count : Int32 = 1,
      bricks = [] of MoanaTypes::BrickRequest

    def initialize
    end
  end

  struct VolumeFilter
    property volume_types = [] of String

    def initialize
    end
  end
end
