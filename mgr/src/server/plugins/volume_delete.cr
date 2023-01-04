require "./helpers"
require "../datastore/*"

delete "/api/v1/pools/:pool_name/volumes/:volume_name" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name, volume_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "Pool does not exist."}.to_json))

  volume = Datastore.get_volume(pool_name, volume_name)
  api_exception(volume.nil?, ({"error": "Volume does not exist."}.to_json))

  api_exception(volume.not_nil!.state == "Started", ({"error": "Volume should be stopped before deleting."}.to_json))

  Datastore.delete_reserved_volume_ports(pool.not_nil!.id, volume.not_nil!.distribute_groups)
  Datastore.delete_volume(pool.not_nil!.id, volume.not_nil!.id)

  env.response.status_code = 204
end
