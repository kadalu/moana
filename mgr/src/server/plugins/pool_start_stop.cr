require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./pool_utils"

ACTION_POOL_START = "pool_start"
ACTION_POOL_STOP  = "pool_stop"

node_action ACTION_POOL_START do |data, _env|
  handle_node_pool_start_stop(data, "start")
end

node_action ACTION_POOL_STOP do |data, _env|
  handle_node_pool_start_stop(data, "stop")
end

def pool_start_stop(env, action)
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, {"error": "The Pool(#{pool_name}) doesn't exists"}.to_json)
  pool = pool.not_nil!

  return pool.to_json if action == "stop" && pool.state == "Stopped"

  nodes = participating_nodes(pool)
  node_details_add_to_pool(pool, nodes)

  # TODO: Add to missed_ops if a node is not reachable

  # Generate Services and Volfiles if Pool to be started
  services, volfiles = services_and_volfiles(pool)

  resp = dispatch_action(
    action == "start" ? ACTION_POOL_START : ACTION_POOL_STOP,
    nodes,
    {services, volfiles, pool}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to #{action} the Pool", resp.node_responses).to_json)

  # Save Services details
  services.each do |node_name, svcs|
    svcs.each do |svc|
      if action == "start"
        # Enable each Services
        Datastore.enable_service(node_name, svc)
      else
        # Disable each Services
        Datastore.disable_service(node_name, svc)
      end
    end
  end

  if pool.state != action
    pool.state = action == "start" ? "Started" : "Stopped"
    Datastore.update_pool_state(pool.id, pool.state)
  end

  pool.to_json
end

post "/api/v1/pools/:pool_name/start" do |env|
  pool_start_stop(env, "start")
end

post "/api/v1/pools/:pool_name/stop" do |env|
  pool_start_stop(env, "stop")
end
