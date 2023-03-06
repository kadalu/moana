require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./pool_utils"

REBALNCE_DIR = "/var/lib/kadalu/rebalance"

ACTION_FIX_LAYOUT_STATUS   = "action_fix_layout_status"
ACTION_MIGRATE_DATA_STATUS = "action_migrate_data_status"

struct RebalanceStatusRequestToNode
  include JSON::Serializable

  property storage_units = [] of MoanaTypes::StorageUnit

  def initialize
  end
end

alias RebalanceRequestToNode = Tuple(String, Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, RebalanceStatusRequestToNode))

def assign_state(status, svc)
  return status if status.state == "not started"

  if svc.running? == false && status.complete == false
    status.state = "failed"
  elsif svc.running? == true
    status.state = "running"
  elsif status.complete == true
    status.state = "complete"
  end

  status
end

node_action ACTION_FIX_LAYOUT_STATUS do |data, _env|
  pool_name, services, request = RebalanceRequestToNode.from_json(data)
  status_file_path = ""
  rebalance_dir = Path.new(WORKDIR, "rebalance", "#{pool_name}").to_s
  request = Hash(String, RebalanceStatusRequestToNode).from_json(request.to_json)
  local_node_id = GlobalConfig.local_node.id
  node_resp = RebalanceStatusRequestToNode.new

  if services.has_key?(local_node_id) && request.has_key?(local_node_id)
    svc = Service.from_json(services[local_node_id][0].to_json)
    storage_unit = request[local_node_id].storage_units[0]
    if svc.id == "rebalance-fix-layout-#{storage_unit.path.gsub("/", "%2F")}"
      status_file_path = "#{rebalance_dir}/#{svc.id}.json"
      if File.exists?(status_file_path)
        storage_unit.fix_layout_status = MoanaTypes::FixLayoutRebalanceStatus.from_json(File.read(status_file_path))
        # Set to 'started' to avoid returning without assigning state in 'assign_state'
        storage_unit.fix_layout_status.state = "started"
      else
        storage_unit.fix_layout_status.state = "not started"
      end
      storage_unit.fix_layout_status = assign_state(storage_unit.fix_layout_status, svc)

      node_resp.storage_units << storage_unit
    end
  end

  NodeResponse.new(true, node_resp.to_json)
end

node_action ACTION_MIGRATE_DATA_STATUS do |data, _env|
  pool_name, services, request = RebalanceRequestToNode.from_json(data)
  status_file_path = ""
  rebalance_dir = Path.new(WORKDIR, "rebalance", "#{pool_name}").to_s
  request = Hash(String, RebalanceStatusRequestToNode).from_json(request.to_json)
  node_resp = RebalanceStatusRequestToNode.new

  unless services[GlobalConfig.local_node.name]?.nil?
    services[GlobalConfig.local_node.name].each do |service|
      request.each do |node_id, storage_units_data|
        next unless node_id == GlobalConfig.local_node.id
        svc = Service.from_json(service.to_json)
        storage_units_data.storage_units.each do |storage_unit|
          next unless svc.id == "rebalance-migrate-data-#{storage_unit.path.gsub("/", "%2F")}"
          status_file_path = "#{rebalance_dir}/#{svc.id}.json"
          if File.exists?(status_file_path)
            storage_unit.migrate_data_status = MoanaTypes::MigrateDataRebalanceStatus.from_json(File.read(status_file_path))
            # Set to 'started' to avoid returning without assigning state in 'assign_state'
            storage_unit.migrate_data_status.state = "started"
          else
            storage_unit.migrate_data_status.state = "not started"
          end
          storage_unit.migrate_data_status = assign_state(storage_unit.migrate_data_status, svc)

          node_resp.storage_units << storage_unit
        end
      end
    end
  end

  NodeResponse.new(true, node_resp.to_json)
end

def construct_fix_layout_service_request(nodes, pool)
  req = Hash(String, RebalanceStatusRequestToNode).new
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new

  # Add only the first existing node & first storage_unit for fix-layout service
  storage_unit = pool.distribute_groups[0].storage_units[0]
  req[storage_unit.node.name] = RebalanceStatusRequestToNode.new if req[storage_unit.node.name]?.nil?
  req[storage_unit.node.name].storage_units << storage_unit
  services = add_fix_layout_service(services, pool.name, nodes[0],
    pool.distribute_groups[0].storage_units[0])

  {req, services}
end

def construct_migrate_data_service_request(pool)
  req = Hash(String, RebalanceStatusRequestToNode).new
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new

  pool.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    req[storage_unit.node.name] = RebalanceStatusRequestToNode.new if req[storage_unit.node.name]?.nil?
    req[storage_unit.node.name].storage_units << storage_unit

    services = add_migrate_data_service(services, pool.name,
      dist_grp.storage_units[0].node, storage_unit)
  end

  {req, services}
end

get "/api/v1/pools/:pool_name/rebalance_status" do |env|
  pool_name = env.params.url["pool_name"]

  total_migrate_data_processes = 0
  total_non_started_migrate_data_processes = 0
  total_completed_migrate_data_processes = 0
  total_failed_migrate_data_processes = 0
  rebalance_status = ""
  highest_estimate_seconds = -2147483648
  sum_of_scanned_bytes = 0
  sum_of_total_bytes = 0
  sum_of_progress = 0

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, {"error": "Pool doesn't exists"}.to_json)
  pool = pool.not_nil!

  nodes = participating_nodes(pool)

  # TODO: Add to missed_ops if a node is not reachable [Check if this is required, since node ping check is done]

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, nodes)
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  request, services = construct_fix_layout_service_request(nodes, pool)
  first_node = [] of MoanaTypes::Node
  first_node << nodes[0]
  resp = dispatch_action(
    ACTION_FIX_LAYOUT_STATUS,
    first_node,
    {pool_name, services, request}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get fix-layout status of pool #{pool.name}", resp.node_responses).to_json)

  storage_unit = pool.distribute_groups[0].storage_units[0]
  if resp.node_responses[storage_unit.node.name].ok
    node_resp = RebalanceStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.name].response)
    su = node_resp.storage_units[0]
    if su.node.id == storage_unit.node.id && su.path == storage_unit.path
      storage_unit.fix_layout_status = su.fix_layout_status

      # Set fix-layout rebalance status summary at pool-level
      pool.fix_layout_summary.state = su.fix_layout_status.state
      pool.fix_layout_summary.total_dirs_scanned = su.fix_layout_status.total_dirs
      pool.fix_layout_summary.duration_seconds = su.fix_layout_status.duration_seconds
    end
  end

  request, services = construct_migrate_data_service_request(pool)
  resp = dispatch_action(
    ACTION_MIGRATE_DATA_STATUS,
    nodes,
    {pool_name, services, request}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get migrate-data status of pool #{pool.name}", resp.node_responses).to_json)

  pool.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    if resp.node_responses[storage_unit.node.name].ok
      node_resp = RebalanceStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.name].response)
      node_resp.storage_units.each do |s_unit|
        if s_unit.node.id == storage_unit.node.id && s_unit.path == storage_unit.path
          storage_unit.migrate_data_status = s_unit.migrate_data_status

          # Counters for Migrate-Data Summary at pool-level
          if s_unit.migrate_data_status.estimate_seconds.to_i64 > highest_estimate_seconds
            highest_estimate_seconds = s_unit.migrate_data_status.estimate_seconds.to_i64
          end

          sum_of_scanned_bytes += s_unit.migrate_data_status.scanned_bytes.to_i64
          sum_of_total_bytes += s_unit.migrate_data_status.total_bytes.to_i64
          sum_of_progress += s_unit.migrate_data_status.progress.to_i64

          total_migrate_data_processes += 1
          case s_unit.migrate_data_status.state
          when "not started"
            total_non_started_migrate_data_processes += 1
          when "complete"
            total_completed_migrate_data_processes += 1
          when "failed"
            total_failed_migrate_data_processes += 1
          end
        end
      end
    end
  end

  # Evaluate rebalance_status from counters and set to Pool
  if total_completed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "complete"
  elsif total_failed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "fail"
  elsif total_non_started_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "not started"
  else
    rebalance_status = "partial"
  end

  pool.migrate_data_summary.total_migrate_data_processes = total_migrate_data_processes
  pool.migrate_data_summary.total_non_started_migrate_data_processes = total_non_started_migrate_data_processes
  pool.migrate_data_summary.total_completed_migrate_data_processes = total_completed_migrate_data_processes
  pool.migrate_data_summary.total_failed_migrate_data_processes = total_failed_migrate_data_processes

  pool.migrate_data_summary.avg_of_scanned_bytes = (sum_of_scanned_bytes/total_migrate_data_processes).to_i64
  pool.migrate_data_summary.avg_of_total_bytes = (sum_of_total_bytes/total_migrate_data_processes).to_i64
  pool.migrate_data_summary.avg_of_progress = sum_of_progress/total_migrate_data_processes
  pool.migrate_data_summary.highest_estimate_seconds = highest_estimate_seconds.to_i64

  pool.migrate_data_summary.state = rebalance_status

  env.response.status_code = 200
  pool.to_json
end
