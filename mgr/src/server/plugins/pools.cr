require "./helpers"
require "../datastore/*"

post "/api/v1/pools" do |env|
  name = env.params.json["name"].as(String)

  if Datastore.agent?
    # TODO: Reroute request to the Storage Manager
    halt(env, status_code: 400, response: ({"error": "Agent doesn't handle requests"}.to_json))
  end

  unless Datastore.maintainer?(env.user_id, "all")
    halt(env, status_code: 403, response: ({"error": "Forbidden"}.to_json))
  end

  # TODO: Pool name validations
  env.response.status_code = 201

  # If this is the first Pool then set as Manager
  if !Datastore.pools_exists? && !Datastore.belongs_to_a_pool?
    Datastore.set_manager
    GlobalConfig.agent = false
  end

  # If Pool already exists then Store returns the Pool object
  # TODO: Handle if Datastore is down or any other errors
  pool = Datastore.create_pool(name)

  pool.to_json
end

get "/api/v1/pools" do |env|
  Datastore.list_pools(env.user_id).to_json
end
