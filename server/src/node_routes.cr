require "kemal"

require "./db/*"

get "/api/v1/clusters/:cluster_id/nodes" do |env|
  MoanaDB.list_nodes(env.params.url["cluster_id"]).to_json
end

get "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
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

  env.response.status_code = 201
  MoanaDB.create_node(env.params.url["cluster_id"], hostname, endpoint).to_json
end

put "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
  hostname = env.params.json["hostname"]?.as(String?)
  endpoint = env.params.json["endpoint"]?.as(String?)

  MoanaDB.update_node(env.params.url["id"], hostname, endpoint).to_json
end

delete "/api/v1/clusters/:cluster_id/nodes/:id" do |env|
  MoanaDB.delete_node(env.params.url["id"])

  env.response.status_code = 204
  nil
end
