require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

ACTION_VOLUME_OPTION_CHANGE = "volume_option_change"

node_action ACTION_VOLUME_OPTION_CHANGE do |data, _env|
  services, volfiles, _ = VolumeRequestToNode.from_json(data)

  # Save all newly generated Volfiles
  if !volfiles[GlobalConfig.local_node.id]?.nil?
    Dir.mkdir_p(Path.new(GlobalConfig.workdir, "volfiles"))
    volfiles[GlobalConfig.local_node.id].each do |volfile|
      File.write(Path.new(GlobalConfig.workdir, "volfiles", "#{volfile.name}.vol"), volfile.content)
    end
  end

  # Send SIGHUP to all the processes (Storage Unit and SHD processes)
  unless services[GlobalConfig.local_node.id]?.nil?
    services[GlobalConfig.local_node.id].each do |service|
      svc = Service.from_json(service.to_json)
      svc.signal(Signal::HUP)
    end
  end

  NodeResponse.new(true, "")
end

# POST /api/v1/pools/:pool_id/volumes/:volume_id/options/set
post "/api/v1/pools/:pool_name/volumes/:volume_name/options/set" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  volume_options = Hash(String, String).from_json(env.request.body.not_nil!)
  volume.options = volume.options.merge(volume_options)

  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options)

  volume = Datastore.get_volume(pool_name, volume_name)

  nodes = participating_nodes(pool_name, volume)

  # Regenerate the Volfiles
  services, volfiles = services_and_volfiles(volume.not_nil!)

  # Notify all the Storage Units
  resp = dispatch_action(
    ACTION_VOLUME_OPTION_CHANGE,
    pool_name,
    nodes,
    {services, volfiles, volume}.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: (node_errors("Failed to notify Storage units on Option change", resp.node_responses).to_json))
  end

  env.response.status_code = 201
  volume.to_json
end

# POST /api/v1/pools/:pool_id/volumes/:volume_id/options/reset
post "/api/v1/pools/:pool_name/volumes/:volume_name/options/reset" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  volume_option_keys = Array(String).from_json(env.request.body.not_nil!)
  volume.options = volume.options.reject(volume_option_keys)

  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options)

  volume = Datastore.get_volume(pool_name, volume_name)

  nodes = participating_nodes(pool_name, volume)

  # Regenerate the Volfiles
  services, volfiles = services_and_volfiles(volume.not_nil!)

  # Notify all the Storage Units
  resp = dispatch_action(
    ACTION_VOLUME_OPTION_CHANGE,
    pool_name,
    nodes,
    {services, volfiles, volume}.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: (node_errors("Failed to notify Storage units on Option change", resp.node_responses).to_json))
  end

  env.response.status_code = 201
  volume.to_json
end
