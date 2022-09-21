require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

ACTION_VOLUME_START = "volume_start"
ACTION_VOLUME_STOP  = "volume_stop"

node_action ACTION_VOLUME_START do |data, _env|
  handle_node_volume_start_stop(data, "start")
end

node_action ACTION_VOLUME_STOP do |data, _env|
  handle_node_volume_start_stop(data, "stop")
end

def volume_start_stop(env, action)
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  return forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name, volume_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    env.response.status_code = 400
    return {"error": "The Pool(#{pool_name}) doesn't exists"}.to_json
  end

  volume = Datastore.get_volume(pool_name, volume_name)

  if volume.nil?
    env.response.status_code = 400
    return {"error": "Volume doesn't exists"}.to_json
  end

  return volume.to_json if action == "stop" && volume.state == "Stopped"

  nodes = participating_nodes(pool_name, volume)
  node_details_add_to_volume(volume, nodes)

  # TODO: Add to missed_ops if a node is not reachable

  # Generate Services and Volfiles if Volume to be started
  services, volfiles = services_and_volfiles(volume)

  resp = dispatch_action(
    action == "start" ? ACTION_VOLUME_START : ACTION_VOLUME_STOP,
    pool_name,
    nodes,
    {services, volfiles, volume}.to_json
  )

  if !resp.ok
    env.response.status_code = 400
    return node_errors("Failed to #{action} the Volume", resp.node_responses).to_json
  end

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

  if volume.state != action
    volume.state = action == "start" ? "Started" : "Stopped"
    Datastore.update_volume_state(volume.id, volume.state)
  end

  volume.to_json
end

post "/api/v1/pools/:pool_name/volumes/:volume_name/start" do |env|
  volume_start_stop(env, "start")
end

post "/api/v1/pools/:pool_name/volumes/:volume_name/stop" do |env|
  volume_start_stop(env, "stop")
end
