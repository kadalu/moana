require "../datastore/*"

post "/api/v1/pools/:pool_name/volumes/:volume_name/rename" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  new_pool_name = env.params.json["new_pool_name"].as(String)
  new_volname = env.params.json["new_volname"].as(String)

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name, volume_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool does not exist."}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "Volume does not exist."}.to_json))
  end

  if new_pool_name != pool_name
    halt(env, status_code: 400, response: ({"error": "Volume rename outside the pool #{pool_name} is not supported."}.to_json))
  end

  if volume_name == new_volname
    halt(env, status_code: 400, response: ({"error": "Existing & New volname are the same."}.to_json))
  end

  if volume.state == "Started"
    halt(env, status_code: 400, response: ({"error": "Volume should be stopped before renaming."}.to_json))
  end

  Datastore.rename_volume(pool.id, volume.id, new_volname)

  volume.name = new_volname

  env.response.status_code = 200

  volume.to_json
end
