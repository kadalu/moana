require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

REBALNCE_DIR = "/var/lib/kadalu/rebalance"

ACTION_REBALANCE_STATUS = "action_rebalance_status"

struct RebalanceStatusRequestToNode
  include JSON::Serializable

  property storage_units = [] of MoanaTypes::StorageUnit

  def initialize
  end
end

alias RebalanceRequestToNode = Tuple(String, Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, RebalanceStatusRequestToNode))

# TODO: Assign migrate-data state at volume level
def assign_migrate_data_state(migrate_data_status, svc)
  return migrate_data_status if migrate_data_status.state == "not started"

  if svc.running? == false && migrate_data_status.complete == false
    migrate_data_status.state = "failed"
  elsif svc.running? == true
    migrate_data_status.state = "running"
  elsif migrate_data_status.complete == true
    migrate_data_status.state = "complete"
  end

  migrate_data_status
end

# Calculate the status file with highest estimate_seconds and return that file data from node.
node_action ACTION_REBALANCE_STATUS do |data, _env|
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
          storage_unit.migrate_data_status = assign_migrate_data_state(storage_unit.migrate_data_status, svc)

          node_resp.storage_units << storage_unit
        end
      end
    end
  end

  NodeResponse.new(true, node_resp.to_json)
end

def construct_migrate_data_service_request(volume)
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new

  volume.distribute_groups.each do |dist_grp|
    services = add_migrate_data_service(services, volume.pool.name, volume.name,
      dist_grp.storage_units[0].node, dist_grp.storage_units[0])
  end

  services
end

def rebalance_status_node_request_prepare(pool_name, volume)
  req = Hash(String, RebalanceStatusRequestToNode).new

  volume.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    req[storage_unit.node.id] = RebalanceStatusRequestToNode.new if req[storage_unit.node.id]?.nil?
    req[storage_unit.node.id].storage_units << storage_unit
  end

  req
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

  services = construct_migrate_data_service_request(volume)
  request = rebalance_status_node_request_prepare(pool_name, volume)

  resp = dispatch_action(
    ACTION_REBALANCE_STATUS,
    pool_name,
    nodes,
    {volume_name, services, request}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get rebalance status of volume #{volume.name}", resp.node_responses).to_json)

  volume.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    if resp.node_responses[storage_unit.node.id].ok
      node_resp = RebalanceStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.id].response)
      node_resp.storage_units.each do |su|
        if su.node.id == storage_unit.node.id && su.path == storage_unit.path
          storage_unit.migrate_data_status = su.migrate_data_status
        end
      end
    end
  end

  env.response.status_code = 200
  volume.to_json
end
