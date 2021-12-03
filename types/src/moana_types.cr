require "json"

module MoanaTypes
  struct PoolCreateRequest
    include JSON::Serializable

    property name = ""

    def initialize
    end
  end

  struct Pool
    include JSON::Serializable

    property id = "", name = ""

    def initialize(@id : String, @name : String)
    end

    def initialize
    end
  end

  struct NodeRequest
    include JSON::Serializable

    property name = "", endpoint = "", pool_name = ""

    def initialize
    end
  end

  class Node
    include JSON::Serializable

    property id = "", name = "", state = "", endpoint = "", addresses = [] of String, token = ""

    def initialize
    end
  end

  class Metrics
    include JSON::Serializable
    # TODO: Include CPU, Memory and Uptime details
    property health = "", size_used_bytes : UInt64 = 0, size_free_bytes : UInt64 = 0, inodes_used_count : UInt64 = 0, inodes_free_count : UInt64 = 0

    def initialize
    end
  end

  class StorageUnit
    include JSON::Serializable

    property id = "", node_name = "", port = 0, path = "", node = Node.new, type = "", fs = "", metrics = Metrics.new, service = ServiceUnit.new

    def initialize(@node_name, @port, @path)
    end
  end

  class VolumeDistributeGroup
    include JSON::Serializable

    property storage_units = [] of StorageUnit,
      replica_count = 0,
      arbiter_count = 0,
      disperse_count = 0,
      redundancy_count = 0,
      replica_keyword = "",
      metrics = Metrics.new

    def initialize
    end

    def type
      if @replica_count > 0
        @replica_keyword == "mirror" ? "Mirror" : "Replicate"
      elsif @disperse_count > 0
        "Disperse"
      else
        "Distribute"
      end
    end
  end

  class Volume
    include JSON::Serializable

    property id = "", name = "", state = "", pool_name = "", distribute_groups = [] of VolumeDistributeGroup, no_start = false, options = Hash(String, String).new, metrics = Metrics.new

    def initialize
    end

    def type
      dist_grp = @distribute_groups[0]
      @distribute_groups.size > 1 ? "Distributed #{dist_grp.type}" : dist_grp.type
    end

    def arbiter?
      @distribute_groups[0].arbiter_count > 0
    end

    def replicate_family?
      @distribute_groups.size > 0 && (@distribute_groups[0].replica_count > 0 || @distribute_groups[0].disperse_count > 0)
    end
  end

  struct Volfile
    include JSON::Serializable

    property name = "", content = ""

    def initialize
    end

    def initialize(@name, @content)
    end
  end

  struct ServiceUnit
    include JSON::Serializable

    property id = "", name = "", args = [] of String, pid_file = "", path = "", metrics = Metrics.new

    def initialize
    end
  end

  struct NodeError
    include JSON::Serializable

    property status_code = 200, error : String, node_name : String

    def initialize(@node_name, @status_code, @error)
    end
  end

  struct Error
    include JSON::Serializable

    property error : String, node_errors = [] of NodeError

    def initialize(@error)
    end
  end
end
