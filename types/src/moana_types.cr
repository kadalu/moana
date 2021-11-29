require "json"

module MoanaTypes
  struct ClusterCreateRequest
    include JSON::Serializable

    property name = ""

    def initialize
    end
  end

  struct Cluster
    include JSON::Serializable

    property id = "", name = ""

    def initialize(@id : String, @name : String)
    end

    def initialize
    end
  end

  struct NodeRequest
    include JSON::Serializable

    property name = "", endpoint = "", cluster_name = ""

    def initialize
    end
  end

  struct Node
    include JSON::Serializable

    property id = "", name = "", endpoint = "", addresses = [] of String, token = ""

    def initialize
    end
  end

  class StorageUnit
    include JSON::Serializable

    property id = "", node_name = "", port = 0, path = "", node = Node.new, type = ""

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
      replica_keyword = ""

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

    property id = "", name = "", cluster_name = "", distribute_groups = [] of VolumeDistributeGroup, no_start = false, options = Hash(String, String).new

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

    property id = "", name = "", args = [] of String, pid_file = "", path = ""

    def initialize
    end
  end

  struct Error
    include JSON::Serializable

    property error : String, status_code : Int32 = 0
  end
end
