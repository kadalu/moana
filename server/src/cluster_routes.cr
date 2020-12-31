require "kemal"

require "./db/*"

get "/api/v1/clusters" do
  MoanaDB.list_clusters.to_json
end

get "/api/v1/clusters/:cluster_id" do |env|
  cluster = MoanaDB.get_cluster(env.params.url["cluster_id"])

  if cluster.nil?
    env.response.status_code = 400
    {"error": "Invalid Cluster ID"}.to_json
  else
    cluster.to_json
  end
end

post "/api/v1/clusters" do |env|
  name = env.params.json["name"].as(String)

  env.response.status_code = 201
  MoanaDB.create_cluster(name).to_json
end

put "/api/v1/clusters/:cluster_id" do |env|
  name = env.params.json["name"].as(String)
  MoanaDB.update_cluster(env.params.url["cluster_id"], name).to_json
end

delete "/api/v1/clusters/:cluster_id" do |env|
  MoanaDB.delete_cluster(env.params.url["cluster_id"])

  env.response.status_code = 204
  nil
end
