require "./helpers"
require "../datastore/*"

delete "/api/v1/pools/:pool_name/volumes/:volume_name" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name, volume_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool does not exist."}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "Volume does not exist."}.to_json))
  end

  if volume.state == "Started"
    halt(env, status_code: 400, response: ({"error": "Volume should be stopped before deleting."}.to_json))
  end

  Datastore.delete_reserved_volume_ports(pool.id, volume.distribute_groups)
  Datastore.delete_volume(pool.id, volume.id)

  env.response.status_code = 204
end
