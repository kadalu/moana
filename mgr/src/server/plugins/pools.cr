require "./helpers"
require "../datastore/*"

post "/api/v1/pools" do |env|
  name = env.params.json["name"].as(String)

  # TODO: Pool name validations
  env.response.status_code = 201

  # If Pool already exists then Store returns the Pool object
  # TODO: Handle if Datastore is down or any other errors
  pool = Datastore.create_pool(name)
  pool.to_json
end

get "/api/v1/pools" do
  Datastore.list_pools.to_json
end
