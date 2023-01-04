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

  # TODO: Reroute request to the Storage Manager
  api_exception(Datastore.agent?, ({"error": "Agent doesn't handle requests"}.to_json))

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, "all"))

  pool = Datastore.get_pool(name)

  api_exception(!pool.nil?, ({"error": "Pool already exists"}.to_json))

  # TODO: Pool name validations
  env.response.status_code = 201

  pool = create_pool(name)

  pool.to_json
end

get "/api/v1/pools" do |env|
  Datastore.list_pools(env.user_id).to_json
end

get "/api/v1/pools/:pool_name" do |env|
  pool_name = env.params.url["pool_name"]
  Datastore.get_pool(env.user_id, pool_name).to_json
end

delete "/api/v1/pools/:pool_name" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.admin?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "Pool does not exist"}.to_json))
  pool = pool.not_nil!

  api_exception(Datastore.nodes_in_pool?(pool.id), ({"error": "One or more nodes are part of this pool"}.to_json))

  Datastore.delete_pool(pool.id)

  env.response.status_code = 204
end

post "/api/v1/pools/:pool_name/rename" do |env|
  name = env.params.url["pool_name"].as(String)
  new_pool_name = env.params.json["new_pool_name"].as(String)

  forbidden_api_exception(!Datastore.admin?(env.user_id, name))

  pool = Datastore.get_pool(name)
  api_exception(pool.nil?, ({"error": "Pool does not exist"}.to_json))
  pool = pool.not_nil!

  api_exception(name == new_pool_name, ({"error": "Existing & New pool names are the same!"}.to_json))

  Datastore.rename_pool_name(pool.id, new_pool_name)

  pool.name = new_pool_name

  # TODO: Pool name validations
  env.response.status_code = 200

  pool.to_json
end
