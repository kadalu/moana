require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

def rebalance_start_stop(env, action)
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name, volume_name))

  volume = Datastore.get_volume(pool_name, volume_name)
  api_exception(volume.nil?, {"error": "Volume doesn't exists"}.to_json)
  volume = volume.not_nil!
  pool = volume.not_nil!.pool

  nodes = participating_nodes(pool_name, volume)

  # TODO: Add to missed_ops if a node is not reachable [Check if this is required, since node ping check is done]

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, pool_name, nodes, "")
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  # Generate Services and Volfiles if Volume to be started
  services, volfiles = services_and_volfiles(volume)

  # Node list where migrate data process is to be run.
  migrate_data_nodes = [] of String

  # Add node of first storage_unit of every distribute group
  volume.not_nil!.distribute_groups.each do |dist_grp|
    services = add_migrate_data_service(services, pool.not_nil!.name, volume.not_nil!.name,
      dist_grp.storage_units[0].node, dist_grp.storage_units[0])
    migrate_data_nodes.push(dist_grp.storage_units[0].node.name)
  end

  resp = dispatch_action(
    ACTION_MANAGE_SERVICES,
    pool_name,
    Datastore.get_nodes(pool_name, migrate_data_nodes.uniq),
    {services, volfiles, volume, action}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to #{action} rebalancing of Volume", resp.node_responses).to_json)

  # Save Services details
  services.each do |node_id, svcs|
    svcs.each do |svc|
      if action == "start"
        # Enable each Services
        Datastore.enable_service(pool.id, node_id, svc)
      else
        # Disable each Services
        Datastore.disable_service(pool.id, node_id, svc)
      end
    end
  end

  env.response.status_code = 200
  volume.to_json
end

post "/api/v1/pools/:pool_name/volumes/:volume_name/rebalance_start" do |env|
  rebalance_start_stop(env, "start")
end

post "/api/v1/pools/:pool_name/volumes/:volume_name/rebalance_stop" do |env|
  rebalance_start_stop(env, "stop")
end
