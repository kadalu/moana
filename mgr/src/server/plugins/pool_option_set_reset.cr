require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./pool_utils.cr"

ACTION_POOL_OPTION_CHANGE = "pool_option_change"

node_action ACTION_POOL_OPTION_CHANGE do |data, _env|
  services, volfiles, _ = PoolRequestToNode.from_json(data)

  save_volfiles(volfiles)
  sighup_processes(services)

  NodeResponse.new(true, "")
end

post "/api/v1/pools/:pool_name/options/set" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))

  pool = pool.not_nil!

  pool_options = Hash(String, String).from_json(env.request.body.not_nil!)
  pool.options = pool.options.merge(pool_options)

  # update volume options to DB.
  Datastore.update_pool_options(pool.id, pool.options)

  nodes = participating_nodes(pool)

  # Regenerate the Volfiles
  services, volfiles = services_and_volfiles(pool)

  # Notify all the Storage Units
  resp = dispatch_action(
    ACTION_POOL_OPTION_CHANGE,
    nodes,
    {services, volfiles, pool}.to_json
  )

  api_exception(!resp.ok, (node_errors("Failed to notify Storage units on Option change", resp.node_responses).to_json))

  env.response.status_code = 201
  pool.to_json
end

post "/api/v1/pools/:pool_name/options/reset" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))

  pool = pool.not_nil!

  pool_option_keys = Array(String).from_json(env.request.body.not_nil!)
  pool.options = pool.options.reject(pool_option_keys)

  # update volume options to DB.
  Datastore.update_pool_options(pool.id, pool.options)

  nodes = participating_nodes(pool)

  # Regenerate the Volfiles
  services, volfiles = services_and_volfiles(pool)

  # Notify all the Storage Units
  resp = dispatch_action(
    ACTION_POOL_OPTION_CHANGE,
    nodes,
    {services, volfiles, pool}.to_json
  )

  api_exception(!resp.ok, (node_errors("Failed to notify Storage units on Option change", resp.node_responses).to_json))

  env.response.status_code = 201
  pool.to_json
end
