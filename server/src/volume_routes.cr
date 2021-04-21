require "json"

require "kemal"
require "moana_types"

require "./db/*"
require "./volume_utils"
require "./helpers"

TASK_VOLUME_CREATE       = "volume_create"
TASK_VOLUME_CREATE_START = "volume_create_start"
TASK_VOLUME_START        = "volume_start"
TASK_VOLUME_STOP         = "volume_stop"
TASK_VOLUME_DELETE       = "volume_delete"
TASK_VOLUME_EXPAND       = "volume_expand"

get "/api/v1/clusters/:cluster_id/volumes" do |env|
  MoanaDB.list_volumes(env.get("user_id").as(String), env.params.url["cluster_id"]).to_json
end

get "/api/v1/clusters/:cluster_id/volumes/:volume_id" do |env|
  if !volume_viewer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  volume = MoanaDB.get_volume(env.params.url["volume_id"])
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    volume.to_json
  end
end

post "/api/v1/clusters/:cluster_id/volumes" do |env|
  if !cluster_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

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
  rescue ex : MoanaTypes::VolumeException
    env.response.status_code = 400
    {"error": ex.message}.to_json
  end
end

def volume_action(env, cluster_id, volume_id, action)
  # TODO: Handle Unknown action
  task_type = TASK_VOLUME_START
  task_type = TASK_VOLUME_STOP if action == "stop"

  volume = MoanaDB.get_volume(volume_id)
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    # First participating node to assign task
    node_id = volume.first_node_id

    MoanaDB.create_task(cluster_id, node_id, task_type, volume.to_json).to_json
  end
end

post "/api/v1/clusters/:cluster_id/volumes/:volume_id/start" do |env|
  if !volume_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  volume_action(env, env.params.url["cluster_id"], env.params.url["volume_id"], "start")
end

post "/api/v1/clusters/:cluster_id/volumes/:volume_id/stop" do |env|
  if !volume_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  volume_action(env, env.params.url["cluster_id"], env.params.url["volume_id"], "stop")
end

post "/api/v1/clusters/:cluster_id/volumes/:volume_id/expand" do |env|
  if !volume_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  req = MoanaTypes::VolumeExpandRequest.from_json(env.request.body.not_nil!)

  begin
    volume = MoanaDB.get_volume(env.params.url["volume_id"])
    if volume.nil?
      env.response.status_code = 400
      {"error": "Invalid Volume ID"}.to_json
    else
      req.validate!(volume, env.params.url["cluster_id"])

      volume = volume_from_request(volume, req)
      # First participating node to assign task
      node_id = volume.first_node_id

      # node hostname and endpoint may not be available
      # Query from Db and update the Volume struct
      nodes = MoanaDB.list_nodes(volume.participating_nodes)
      volume = update_node_details(volume, nodes)

      task = MoanaDB.create_task(env.params.url["cluster_id"],
        node_id,
        TASK_VOLUME_EXPAND,
        volume.to_json)
      env.response.status_code = 200
      task.to_json
    end
  rescue ex : MoanaTypes::VolumeException
    env.response.status_code = 400
    {"error": ex.message}.to_json
  end
end

delete "/api/v1/clusters/:cluster_id/volumes/:volume_id" do |env|
  if !volume_admin?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  task_type = TASK_VOLUME_DELETE

  volume = MoanaDB.get_volume(env.params.url["volume_id"])
  if volume.nil?
    env.response.status_code = 400
    {"error": "Invalid Volume ID"}.to_json
  else
    # First participating node to assign task
    node_id = volume.first_node_id

    MoanaDB.create_task(env.params.url["cluster_id"], node_id, task_type, volume.to_json).to_json
  end
end
