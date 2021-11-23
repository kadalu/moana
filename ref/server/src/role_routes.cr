require "openssl"

require "kemal"

require "./db/*"
require "./helpers"

post "/api/v1/roles" do |env|
  cluster_id = env.params.json["cluster_id"].as(String)
  volume_id = env.params.json["volume_id"].as(String)
  user_id = env.params.json["user_id"].as(String)
  name = env.params.json["name"].as(String)

  if volume_id == "all"
    if !MoanaDB.role_cluster_admin?(env.get("user_id").as(String), cluster_id)
      halt(env, status_code: 403, response: forbidden_response)
    end
  else
    if !MoanaDB.role_volume_admin?(env.get("user_id").as(String), cluster_id, volume_id)
      halt(env, status_code: 403, response: forbidden_response)
    end
  end

  env.response.status_code = 201
  MoanaDB.create_role(cluster_id, user_id, volume_id, name).to_json
end

delete "/api/v1/roles/:user_id/:cluster_id/:volume_id/:name" do |env|
  self_user = env.get("user_id").as(String) == env.params.url["user_id"]

  if env.params.url["volume_id"] == "all" && !self_user
    if !cluster_admin?(env)
      halt(env, status_code: 403, response: forbidden_response)
    end
  elsif !self_user
    if !volume_admin?(env)
      halt(env, status_code: 403, response: forbidden_response)
    end
  end

  MoanaDB.delete_role(
    env.params.url["user_id"],
    env.params.url["cluster_id"],
    env.params.url["volume_id"],
    env.params.url["name"]
  )

  env.response.status_code = 204
  nil
end
