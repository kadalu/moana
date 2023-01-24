require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

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

# TODO: Assign state at volume level
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
  volume_name, services, request = RebalanceRequestToNode.from_json(data)
  status_file_path = ""
  rebalance_dir = Path.new(WORKDIR, "rebalance", "#{volume_name}").to_s
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
  volume_name, services, request = RebalanceRequestToNode.from_json(data)
  status_file_path = ""
  rebalance_dir = Path.new(WORKDIR, "rebalance", "#{volume_name}").to_s
  request = Hash(String, RebalanceStatusRequestToNode).from_json(request.to_json)
  node_resp = RebalanceStatusRequestToNode.new

  unless services[GlobalConfig.local_node.id]?.nil?
    services[GlobalConfig.local_node.id].each do |service|
      request.each do |node_id, storage_units_data|
        next unless node_id == GlobalConfig.local_node.id
        svc = Service.from_json(service.to_json)
        storage_units_data.storage_units.each do |storage_unit|
          next unless svc.id == "rebalance-migrate-data-#{storage_unit.path.gsub("/", "%2F")}"
          status_file_path = "#{rebalance_dir}/#{svc.id}.json"
          if File.exists?(status_file_path)
            storage_unit.migrate_data_status = MoanaTypes::MigrateDataRebalanceStatus.from_json(File.read(status_file_path))
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

def construct_fix_layout_service_request(pool_name, nodes, volume)
  req = Hash(String, RebalanceStatusRequestToNode).new
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new

  # Add only the first existing node & first storage_unit for fix-layout service
  storage_unit = volume.distribute_groups[0].storage_units[0]
  req[storage_unit.node.id] = RebalanceStatusRequestToNode.new if req[storage_unit.node.id]?.nil?
  req[storage_unit.node.id].storage_units << storage_unit
  services = add_fix_layout_service(services, pool_name, volume.name, nodes[0],
    volume.distribute_groups[0].storage_units[0])

  {req, services}
end

def construct_migrate_data_service_request(pool_name, volume)
  req = Hash(String, RebalanceStatusRequestToNode).new
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new

  volume.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    req[storage_unit.node.id] = RebalanceStatusRequestToNode.new if req[storage_unit.node.id]?.nil?
    req[storage_unit.node.id].storage_units << storage_unit

    services = add_migrate_data_service(services, volume.pool.name, volume.name,
      dist_grp.storage_units[0].node, storage_unit)
  end

  {req, services}
end

get "/api/v1/pools/:pool_name/volumes/:volume_name/rebalance_status" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name, volume_name))

  volume = Datastore.get_volume(pool_name, volume_name)
  api_exception(volume.nil?, {"error": "Volume doesn't exists"}.to_json)
  volume = volume.not_nil!

  nodes = participating_nodes(pool_name, volume)

  # TODO: Add to missed_ops if a node is not reachable [Check if this is required, since node ping check is done]

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, pool_name, nodes, "")
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  request, services = construct_fix_layout_service_request(pool_name, nodes, volume)
  first_node = [] of MoanaTypes::Node
  first_node << nodes[0]
  resp = dispatch_action(
    ACTION_FIX_LAYOUT_STATUS,
    pool_name,
    first_node,
    {volume_name, services, request}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get fix-layout status of volume #{volume.name}", resp.node_responses).to_json)

  storage_unit = volume.distribute_groups[0].storage_units[0]
  if resp.node_responses[storage_unit.node.id].ok
    node_resp = RebalanceStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.id].response)
    su = node_resp.storage_units[0]
    if su.node.id == storage_unit.node.id && su.path == storage_unit.path
      storage_unit.fix_layout_status = su.fix_layout_status
    end
  end

  request, services = construct_migrate_data_service_request(pool_name, volume)
  resp = dispatch_action(
    ACTION_MIGRATE_DATA_STATUS,
    pool_name,
    nodes,
    {volume_name, services, request}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get migrate-data status of volume #{volume.name}", resp.node_responses).to_json)

  volume.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    if resp.node_responses[storage_unit.node.id].ok
      node_resp = RebalanceStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.id].response)
      node_resp.storage_units.each do |s_unit|
        if s_unit.node.id == storage_unit.node.id && s_unit.path == storage_unit.path
          storage_unit.migrate_data_status = s_unit.migrate_data_status
        end
      end
    end
  end

  env.response.status_code = 200
  volume.to_json
end
