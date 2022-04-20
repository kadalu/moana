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

    property id = "", name = "", nodes = [] of Node

    def initialize(@id : String, @name : String)
    end

    def initialize
    end
  end

  struct NodeRequest
    include JSON::Serializable

    property name = "", endpoint = "", pool_name = "", mgr_node_id = "",
      mgr_url = "", mgr_port = 3000, mgr_https = false, mgr_token = ""

    def initialize
    end
  end

  class Node
    include JSON::Serializable

    property id = "", name = "", state = "", endpoint = "", addresses = [] of String, token = "", pool = Pool.new

    def initialize
    end
  end

  class Metrics
    include JSON::Serializable
    # TODO: Include CPU, Memory and Uptime details
    property health = "",
      size_bytes : Int64 = 0,
      inodes_count : Int64 = 0,
      size_used_bytes : Int64 = 0,
      size_free_bytes : Int64 = 0,
      inodes_used_count : Int64 = 0,
      inodes_free_count : Int64 = 0

    def initialize
    end
  end

  class StorageUnit
    include JSON::Serializable

    property id = "",
      port = 0,
      path = "",
      node = Node.new,
      type = "",
      fs = "",
      metrics = Metrics.new,
      service = ServiceUnit.new

    def initialize(node_name, @port, @path)
      @node.name = node_name
    end

    def initialize
    end
  end

  class DistributeGroup
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

  class Backup
    include JSON::Serializable

    property backupdir = ""

    def initialize(@backupdir : String)
    end

    def initialize
    end

  end

  class Volume
    include JSON::Serializable

    property id = "",
      name = "",
      state = "",
      pool = Pool.new,
      distribute_groups = [] of DistributeGroup,
      no_start = false,
      volume_id = "",
      auto_create_pool = false,
      auto_add_nodes = false,
      options = Hash(String, String).new,
      metrics = Metrics.new,
      snapshot_plugin = ""

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

    property id = "", name = "", args = [] of String, pid_file = "", path = "", metrics = Metrics.new, wait = true, create_pid_file = true

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

  struct User
    include JSON::Serializable

    property id = "", username = "", name = "", password = "", roles = [] of Role, new_password = ""

    def initialize
    end
  end

  struct Role
    include JSON::Serializable

    property user_id = "", pool_id = "", volume_id = "", role = ""

    def initialize
    end
  end

  struct ApiKey
    include JSON::Serializable

    property id = "", token = "", name = "", user_id = "", username = ""

    def initialize
    end
  end
end
