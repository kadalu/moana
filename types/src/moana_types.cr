require "json"
require "db"

module MoanaTypes
  struct Info
    include JSON::Serializable

    property manager_url = "", version = ""

    def initialize
    end
  end

  struct NodeRequest
    include JSON::Serializable

    property name = "", endpoint = "", mgr_node_id = "",
      mgr_url = "", mgr_port = 3000, mgr_https = false, mgr_token = "",
      mgr_hostname = ""

    def initialize
    end
  end

  class Node
    include JSON::Serializable
    include DB::Serializable

    property id = "", name = "", state = "", endpoint = "", addresses = [] of String, token = ""

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

  struct HealMetrics
    include JSON::Serializable
    # TODO: Include CPU, Memory and Uptime details
    property heal_status : String = "Not Connected",
      heal_total : Int64 = -1,
      heal_pending_count : Int64 = -1,
      heal_split_brain_count : Int64 = -1,
      heal_possibly_healing_count : Int64 = -1,
      heal_pending_files = [] of Tuple(String, String)

    def initialize
    end
  end

  class PoolMeta
    include JSON::Serializable

    property id = "", name = ""

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
      service = ServiceUnit.new,
      metrics = Metrics.new,
      heal_metrics = HealMetrics.new,
      fix_layout_status = FixLayoutRebalanceStatus.new,
      migrate_data_status = MigrateDataRebalanceStatus.new,
      volume = PoolMeta.new

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
      if @replica_count >= 2 && @arbiter_count == 1
        "Arbiter"
      elsif @replica_count > 0
        @replica_keyword == "mirror" ? "Mirror" : "Replicate"
      elsif @disperse_count > 0
        "Disperse"
      else
        "Distribute"
      end
    end
  end

  class Pool
    include JSON::Serializable

    property id = "",
      name = "",
      state = "",
      distribute = false,
      distribute_groups = [] of DistributeGroup,
      no_start = false,
      pool_id = "",
      auto_create_pool = false,
      auto_add_nodes = false,
      options = Hash(String, String).new,
      metrics = Metrics.new,
      snapshot_plugin = "",
      fix_layout_summary = FixLayoutRebalanceSummary.new,
      migrate_data_summary = MigrateDataRebalanceSummary.new

    def initialize
    end

    def type
      dist_grp = @distribute_groups[0]
      if @distribute_groups.size > 1 && dist_grp.type != "Distribute"
        "Distributed #{dist_grp.type}"
      else
        dist_grp.type
      end
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

    property user_id = "", pool_id = "", role = ""

    def initialize
    end
  end

  struct ApiKey
    include JSON::Serializable

    property id = "", token = "", name = "", user_id = "", username = ""

    def initialize
    end
  end

  struct ConfigSnapshot
    include JSON::Serializable

    property name = "", overwrite = false, created_on = "",
      snaps_rootdir = "/var/lib/kadalu/config-snapshots"

    def initialize
    end
  end

  struct MigrateDataRebalanceSummary
    include JSON::Serializable

    property total_non_started_migrate_data_processes = 0,
      total_completed_migrate_data_processes = 0,
      total_failed_migrate_data_processes = 0,
      total_migrate_data_processes = 0,
      avg_of_scanned_bytes = 0_i64, avg_of_total_bytes = 0_i64,
      avg_of_progress = 0.0, highest_estimate_seconds = 0_i64,
      state = "not started"

    def initialize
    end
  end

  struct MigrateDataRebalanceStatus
    include JSON::Serializable

    property complete = false, progress = 0, scanned_bytes = 0_i64,
      total_bytes = 0_i64, duration_seconds = 0, estimate_seconds = 0, state = "not started"

    def initialize
    end
  end

  struct FixLayoutRebalanceSummary
    include JSON::Serializable

    property total_dirs_scanned = 0, duration_seconds = 0, state = "not started"

    def initialize
    end
  end

  struct FixLayoutRebalanceStatus
    include JSON::Serializable

    property complete = false, total_dirs = 0, duration_seconds = 0, state = "not started"

    def initialize
    end
  end
end
