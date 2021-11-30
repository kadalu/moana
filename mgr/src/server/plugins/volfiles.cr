require "./helpers"
require "../conf"
require "../datastore/*"

get "/api/v1/clusters/:cluster_name/volfiles/:volfile_name" do |env|
  # cluster_name = env.params.url["cluster_name"]
  volfile_name = env.params.url["volfile_name"]

  # TODO: List volumes to be implemented
  # volumes = Datastore.list_volumes(cluster_name)
  volumes = [] of MoanaTypes::Volume

  tmpl = volfile_get(volfile_name)
  content = Volfile.cluster_level(volfile_name, tmpl, volumes)
  MoanaTypes::Volfile.new(volfile_name, content).to_json
end

get "/api/v1/clusters/:cluster_name/volumes/:volume_name/volfiles/:volfile_name" do |env|
  cluster_name = env.params.url["cluster_name"]
  volume_name = env.params.url["volume_name"]
  volfile_name = env.params.url["volfile_name"]
  storage_unit = env.params.query["storage_unit"]?

  volume = Datastore.get_volume(cluster_name, volume_name)
  unless volume
    halt(env, status_code: 400, response: ({"error": "Invalid Volume name"}.to_json))
  end

  tmpl = volfile_get(volfile_name)
  content = if storage_unit
              Volfile.storage_unit_level(volfile_name, tmpl, volume, storage_unit)
            else
              Volfile.volume_level(volfile_name, tmpl, volume)
            end

  MoanaTypes::Volfile.new(volfile_name, content).to_json
end
