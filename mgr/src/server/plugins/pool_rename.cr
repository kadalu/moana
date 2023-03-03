require "../datastore/*"

post "/api/v1/pools/:pool_name/rename" do |env|
  pool_name = env.params.url["pool_name"]

  new_name = env.params.json["new_name"].as(String)

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "Pool does not exist."}.to_json))
  pool = pool.not_nil!

  api_exception(pool_name == new_name, ({"error": "Source Pool #{pool_name} and Target Pool #{new_name} are same."}.to_json))

  new_pool = Datastore.get_pool(new_name)

  api_exception(!new_pool.nil?, ({"error": "Target Pool #{new_name} already exist."}.to_json))

  api_exception(pool.state == "Started", ({"error": "Pool should be stopped before renaming."}.to_json))

  Datastore.rename_pool(pool.id, new_name)

  pool.name = new_name

  env.response.status_code = 200

  pool.to_json
end
