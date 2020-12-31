require "json"

require "kemal"
require "moana_types"

require "./db/*"
require "./volume_utils"

TASK_VOLUME_CREATE = "volume_create"
TASK_VOLUME_CREATE_START = "volume_create_start"
TASK_VOLUME_START = "volume_start"
TASK_VOLUME_STOP = "volume_stop"
TASK_VOLUME_DELETE = "volume_delete"


get "/api/v1/clusters/:cluster_id/volumes" do |env|
  MoanaDB.list_volumes(env.params.url["cluster_id"]).to_json
end

get "/api/v1/clusters/:cluster_id/volumes/:id" do |env|
  volume = MoanaDB.get_volume(env.params.url["id"])
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    volume.to_json
  end
end

post "/api/v1/clusters/:cluster_id/volumes" do |env|
  req = MoanaTypes::VolumeCreateRequest.from_json(env.request.body.not_nil!)

  begin
    req.validate!(env.params.url["cluster_id"])
    task_type = TASK_VOLUME_CREATE
    task_type = TASK_VOLUME_CREATE_START if req.start

    volume = volume_from_request(req)
    # First participating node to assign task
    node_id = volume.first_node_id

    # node hostname and endpoint may not be available
    # Query from Db and update the Volume struct
    nodes = MoanaDB.list_nodes(volume.participating_nodes)
    volume = update_node_details(volume, nodes)

    task = MoanaDB.create_task(env.params.url["cluster_id"], node_id, task_type, volume.to_json)
    env.response.status_code = 201
    task.to_json
  rescue ex: MoanaTypes::VolumeException
    env.response.status_code = 400
    {"error": ex.message}.to_json
  end
end

post "/api/v1/clusters/:cluster_id/volumes/:id/:action" do |env|
  # TODO: Handle Unknown action
  task_type = TASK_VOLUME_START
  task_type = TASK_VOLUME_STOP if env.params.url["action"] == "stop"

  volume = MoanaDB.get_volume(env.params.url["id"])
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    # First participating node to assign task
    node_id = volume.first_node_id

    MoanaDB.create_task(env.params.url["cluster_id"], node_id, task_type, volume.to_json).to_json
  end
end

delete "/api/v1/clusters/:cluster_id/volumes/:id" do |env|
  task_type = TASK_VOLUME_DELETE

  volume = MoanaDB.get_volume(env.params.url["id"])
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    # First participating node to assign task
    node_id = volume.first_node_id

    MoanaDB.create_task(env.params.url["cluster_id"], node_id, task_type, volume.to_json).to_json
  end
end
