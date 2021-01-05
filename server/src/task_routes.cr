require "kemal"

require "./db/*"
require "./task"

TASK_STATE_COMPLETED = "Completed"

get "/api/v1/clusters/:cluster_id/tasks" do |env|
  MoanaDB.list_tasks(env.params.url["cluster_id"]).to_json
end

get "/api/v1/tasks/:cluster_id/:node_id" do |env|
  t = MoanaDB.list_tasks(env.params.url["cluster_id"], env.params.url["node_id"]).to_json
  t
end

put "/api/v1/clusters/:cluster_id/tasks/:id" do |env|
  # TODO: Handle Auth Mgmt by validating request is from a Node in Cluster
  state = env.params.json["state"]?.as(String?)
  response = env.params.json["response"]?.as(String?)

  # TODO: Do on_complete and update_task as Transaction

  if state == TASK_STATE_COMPLETED
    if task = MoanaDB.get_task(env.params.url["id"])
      # Convert to JSON and then Convert back to different Type
      # to make automatic handling possible with JSON discrimination.
      # And also this will validate the task Type. If a Task type
      # is not implemented or not handled then below line will
      # raise error.
      server_task = ServerTask.from_json(task.to_json)
      server_task.on_complete
    end
  end

  MoanaDB.update_task(env.params.url["id"], state, response).to_json
end

delete "/api/v1/clusters/:cluster_id/tasks/:id" do |env|
  MoanaDB.delete_task(env.params.url["id"])

  env.response.status_code = 204
  nil
end
