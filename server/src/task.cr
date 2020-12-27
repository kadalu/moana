require "kemal"

require "./db/*"

get "/api/v1/clusters/:cluster_id/tasks" do |env|
  MoanaDB.list_tasks(env.params.url["cluster_id"]).to_json
end

get "/api/v1/tasks/:cluster_id/:node_id" do |env|
  t = MoanaDB.list_tasks(env.params.url["cluster_id"], env.params.url["node_id"]).to_json
  puts t
  t
end

put "/api/v1/clusters/:cluster_id/tasks/:id" do |env|
  state = env.params.json["state"]?.as(String?)
  response = env.params.json["response"]?.as(String?)

  MoanaDB.update_task(env.params.url["id"], state, response).to_json
end

delete "/api/v1/clusters/:cluster_id/tasks/:id" do |env|
  MoanaDB.delete_task(env.params.url["id"])

  env.response.status_code = 204
  nil
end
