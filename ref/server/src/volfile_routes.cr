require "kemal"
require "moana_volgen"

require "./db/*"
require "./default_volfiles"
require "./helpers"

get "/api/v1/clusters/:cluster_id/volfiles/:name" do |env|
  filters = MoanaTypes::VolumeFilter.new

  if env.params.query["volume_types"]?
    filters.volume_types = env.params.query["volume_types"].split(",")
  end

  volumes = MoanaDB.list_volumes(env.get("user_id").as(String), env.params.url["cluster_id"], filters)
  if volumes.size == 0
    {"content" => ""}.to_json
  else
    # TODO: Get Volfile template from Db based on params["name"]
    volfile_content = Volfile.cluster_level(env.params.url["name"], SHD_VOLFILE, volumes)
    if volfile_content == ""
      env.response.status_code = 500
      {status: "failed to get volfile content"}.to_json
    else
      {"content" => volfile_content}.to_json
    end
  end
end

get "/api/v1/clusters/:cluster_id/volfiles/:name/:volume_id" do |env|
  if !volume_client?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  volume = MoanaDB.get_volume(env.params.url["volume_id"])
  if volume.nil?
    env.response.status_code = 500
    {status: "invalid volume id"}.to_json
  else
    # TODO: Get Volfile template from Db based on params["name"]
    volfile_content = Volfile.volume_level(env.params.url["name"], CLIENT_VOLFILE, volume)
    if volfile_content == ""
      env.response.status_code = 500
      {status: "failed to get volfile content"}.to_json
    else
      {"content" => volfile_content}.to_json
    end
  end
end

get "/api/v1/clusters/:cluster_id/volfiles/:name/:volume_id/:brick_id" do |env|
  volume = MoanaDB.get_volume(env.params.url["volume_id"])
  if volume.nil?
    env.response.status_code = 500
    {status: "invalid volume id"}.to_json
  else
    # TODO: Get Volfile template from Db based on params["name"]
    volfile_content = Volfile.brick_level(env.params.url["name"], BRICK_VOLFILE, volume, env.params.url["brick_id"])
    if volfile_content == ""
      env.response.status_code = 500
      {status: "failed to get volfile content"}.to_json
    else
      {"content" => volfile_content}.to_json
    end
  end
end
