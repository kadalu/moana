require "./helpers"
require "../datastore/*"

delete "/api/v1/pools/:pool_name" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "Pool does not exist."}.to_json))

  api_exception(pool.not_nil!.state == "Started", ({"error": "Pool should be stopped before deleting."}.to_json))

  Datastore.delete_reserved_ports(pool.not_nil!.distribute_groups)
  Datastore.delete_pool(pool.not_nil!.id)

  env.response.status_code = 204
end
