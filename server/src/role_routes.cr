require "openssl"

require "kemal"

require "./db/*"

post "/api/v1/roles" do |env|
  cluster_id = env.params.json["cluster_id"].as(String)
  volume_id = env.params.json["volume_id"].as(String)
  user_id = env.params.json["user_id"].as(String)
  name = env.params.json["name"].as(String)

  # TODO: Validate User logged in and ClusterAdmin if volume_id == all
  # Else VolumeAdmin for the given volume_id

  env.response.status_code = 201
  MoanaDB.create_role(cluster_id, user_id, volume_id, name).to_json
end

delete "/api/v1/roles/:user_id/:cluster_id/:volume_id/:name" do |env|
  # TODO: Validate User logged in and ClusterAdmin if volume_id == all
  # Else VolumeAdmin for the given volume_id
  # Or user_id == session.user_id

  MoanaDB.delete_role(
    env.params.url["user_id"],
    env.params.url["cluster_id"],
    env.params.url["volume_id"],
    env.params.url["name"]
  )

  env.response.status_code = 204
  nil
end
