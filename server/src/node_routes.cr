require "kemal"

require "./db/*"
require "./helpers"

get "/api/v1/clusters/:cluster_id/nodes" do |env|
  if !cluster_viewer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  MoanaDB.list_nodes(env.params.url["cluster_id"]).to_json
end

get "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
  if !cluster_viewer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  node = MoanaDB.get_node(env.params.url["id"])
  if node.nil?
    env.response.status_code = 400
    {"error": "Invalid Node ID"}.to_json
  else
    node.to_json
  end
end

post "/api/v1/clusters/:cluster_id/nodes" do |env|
  hostname = env.params.json["hostname"].as(String)
  endpoint = env.params.json["endpoint"].as(String)

  # Generate a Token to use with all future node
  # to Server communications
  token = hash_sha256(UUID.random.to_s)

  env.response.status_code = 201
  MoanaDB.create_node(env.params.url["cluster_id"], hostname, endpoint, token).to_json
end

put "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
  if !cluster_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  hostname = env.params.json["hostname"]?.as(String?)
  endpoint = env.params.json["endpoint"]?.as(String?)

  MoanaDB.update_node(env.params.url["id"], hostname, endpoint).to_json
end

delete "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
  if !cluster_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  MoanaDB.delete_node(env.params.url["id"])

  env.response.status_code = 204
  nil
end
