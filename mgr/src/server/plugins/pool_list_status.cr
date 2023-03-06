require "./helpers"
require "../datastore/*"
require "./pool_utils"

ACTION_POOL_STATUS = "pool_status"

class PoolNotFound < Exception
end

struct PoolStatusRequestToNode
  include JSON::Serializable

  property service_units = [] of MoanaTypes::ServiceUnit, storage_units = [] of MoanaTypes::StorageUnit

  def initialize
  end
end

node_action ACTION_POOL_STATUS do |data, _env|
  Log.debug &.emit("Node Action", action: ACTION_POOL_STATUS, data: data)

  req = Hash(String, PoolStatusRequestToNode).from_json(data)
  resp = PoolStatusRequestToNode.new
  req.each do |node_name, node_data|
    next unless node_name == GlobalConfig.local_node.name

    # Fetch Services Status
    node_data.service_units.each do |service|
      svc = Service.from_json(service.to_json)
      service.metrics.health = svc.running? ? "Up" : "Down"
      # TODO: Collect CPU, Memory and Uptime details
      resp.service_units << service
    end

    node_data.storage_units.each do |storage_unit|
      svc = Service.from_json(storage_unit.service.to_json)
      storage_unit.metrics.health = svc.running? ? "Up" : "Down"
      # TODO: Collect CPU, Memory and Uptime details

      rc, out, err = execute("df", ["-B1", "--output=used,avail,iused,iavail", storage_unit.path])
      unless rc == 0
        Log.error &.emit("Failed to collect Storage Unit Metrics", storage_unit: "#{storage_unit.path}", rc: "#{rc}", error: "#{err.strip}")
        next
      end

      # Example output
      #     Used      Avail IUsed  IFree
      # 41259008 1021997056     3 524285
      _, line = out.strip.split("\n")
      used, avail, iused, ifree = line.split
      storage_unit.metrics.size_used_bytes = used.to_i64
      storage_unit.metrics.size_free_bytes = avail.to_i64
      storage_unit.metrics.size_bytes = used.to_i64 + avail.to_i64
      storage_unit.metrics.inodes_used_count = iused.to_i64
      storage_unit.metrics.inodes_free_count = ifree.to_i64
      storage_unit.metrics.inodes_count = iused.to_i64 + ifree.to_i64
      resp.storage_units << storage_unit
    end
  end

  NodeResponse.new(true, resp.to_json)
end

def pool_status_node_request_prepare(pools)
  req = Hash(String, PoolStatusRequestToNode).new

  # TODO: Generate SHD service one per Pool per Storage node
  pools.each do |pool|
    pool.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        req[storage_unit.node.name] = PoolStatusRequestToNode.new if req[storage_unit.node.name]?.nil?
        # Generate Service Unit
        storage_unit.service = StorageUnitService.new(pool.name, storage_unit).unit
        req[storage_unit.node.name].storage_units << storage_unit
      end
    end
  end

  req
end

def pool_list_detail_status(env, pool_name, state)
  if pool_name == ""
    pools = Datastore.list_pools_by_user(env.user_id)
  else
    p = Datastore.get_pool(pool_name)
    raise PoolNotFound.new("Pool #{pool_name} not found") unless p

    pools = [p]
  end

  return pools.to_json unless state

  nodes = participating_nodes(pools)

  # Collect list of services and Storage Units
  data = pool_status_node_request_prepare(pools)
  resp = dispatch_action(ACTION_POOL_STATUS, nodes, data.to_json)

  pools.each do |pool|
    pool.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        if resp.node_responses[storage_unit.node.name].ok
          node_resp = PoolStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.name].response)
          node_resp.storage_units.each do |su|
            if su.node.name == storage_unit.node.name && su.path == storage_unit.path
              storage_unit.metrics = su.metrics
            end
          end
        end

        if storage_unit.metrics.health == ""
          set_default_storage_unit_metrics(storage_unit)
        end
      end
    end
  end

  # Post process the Metrics to find Pool Health and Pool Utilization
  pools.each do |pool|
    set_pool_metrics(pool)
  end

  pools.to_json
end

get "/api/v1/pools" do |env|
  state = env.params.query["state"]

  pool_list_detail_status(env, "", state ? true : false)
end

get "/api/v1/pools/:pool_name" do |env|
  pool_name = env.params.url["pool_name"]
  state = env.params.query["state"]

  pool_list_detail_status(env, pool_name, state ? true : false)
rescue ex : PoolNotFound
  halt(env, status_code: 400, response: ({"error": "#{ex}"}.to_json))
end
