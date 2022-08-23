require "./helpers"
require "../datastore/*"

def create_pool(name)
  # If this is the first Pool then set as Manager
  if !Datastore.pools_exists? && !Datastore.belongs_to_a_pool?
    Datastore.set_manager
    GlobalConfig.agent = false
  end

  # TODO: Handle if Datastore is down or any other errors
  Datastore.create_pool(name)
end

post "/api/v1/pools" do |env|
  name = env.params.json["name"].as(String)

  if Datastore.agent?
    # TODO: Reroute request to the Storage Manager
    halt(env, status_code: 400, response: ({"error": "Agent doesn't handle requests"}.to_json))
  end

  unless Datastore.maintainer?(env.user_id, "all")
    halt(env, status_code: 403, response: ({"error": "Forbidden"}.to_json))
  end

  pool = Datastore.get_pool(name)

  unless pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool already exists"}.to_json))
  end

  # TODO: Pool name validations
  env.response.status_code = 201

  pool = create_pool(name)

  pool.to_json
end

get "/api/v1/pools" do |env|
  Datastore.list_pools(env.user_id).to_json
end

delete "/api/v1/pools/:pool_name" do |env|
  pool_name = env.params.url["pool_name"]

  next forbidden(env) unless Datastore.admin?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool does not exist"}.to_json))
  end

  if Datastore.nodes_in_pool?(pool.id)
    halt(env, status_code: 400, response: ({"error": "One or more nodes are part of this pool"}.to_json))
  end

  Datastore.delete_pool(pool.id)

  env.response.status_code = 204
end

post "/api/v1/pools/:pool_name/rename" do |env|
  name = env.params.url["pool_name"].as(String)
  new_pool_name = env.params.json["new_pool_name"].as(String)

  next forbidden(env) unless Datastore.admin?(env.user_id, name)

  pool = Datastore.get_pool(name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool does not exist"}.to_json))
  end

  if name == new_pool_name
    halt(env, status_code: 400, response: ({"error": "Existing & New pool names are the same!"}.to_json))
  end

  Datastore.rename_pool_name(pool.id, new_pool_name)

  pool.name = new_pool_name

  # TODO: Pool name validations
  env.response.status_code = 200

  pool.to_json
end
