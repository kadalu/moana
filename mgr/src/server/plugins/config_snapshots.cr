require "moana_types"
require "file_utils"
require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/config-snapshots" do |env|
  data = MoanaTypes::ConfigSnapshot.from_json(env.request.body.not_nil!)
  snap_name = data.name
  if snap_name.strip == ""
    halt(env, status_code: 400, response: ({"error": "Invalid Snapshot name"}.to_json))
  end

  snap_dir = "#{GlobalConfig.workdir}/config-snapshots" + "/#{snap_name}"

  if Dir.exists?(snap_dir)
    unless data.overwrite
      halt(env, status_code: 400, response: ({"error": "Snapshot already exists"}.to_json))
    end

    # Delete the current Snapshot directory if overwrite=true
    FileUtils.rm_rf(snap_dir)
  end

  Dir.mkdir_p snap_dir

  FileUtils.cp("#{GlobalConfig.workdir}/info", snap_dir) if File.exists?("#{GlobalConfig.workdir}/info")

  time = Time.utc.to_s("%Y/%m/%d %H:%M:%s")
  metadata = {"created_on": time}.to_json
  File.write("#{snap_dir}/meta.json", metadata)

  Datastore.dump("#{GlobalConfig.workdir}/meta/kadalu.db", "#{snap_dir}/kadalu_snapshot.db")

  env.response.status_code = 200
  data.created_on = time

  data.to_json
end

delete "/api/v1/config-snapshots/:snap_name" do |env|
  snap_name = env.params.url["snap_name"]

  snap_dir = "#{GlobalConfig.workdir}/config-snapshots" + "/#{snap_name}"

  unless Dir.exists?(snap_dir)
    halt(env, status_code: 400, response: ({"error": "Snapshot doesn't exists"}.to_json))
  end

  FileUtils.rm_rf(snap_dir)

  env.response.status_code = 204
end

get "/api/v1/config-snapshots" do |env|
  snaps = Datastore.list_config_snapshots

  env.response.status_code = 200

  snaps.to_json
end

get "/api/v1/config-snapshots/:snap_name" do |env|
  snap_name = env.params.url["snap_name"]

  snap = Datastore.get_config_snapshot(snap_name)

  if snap.nil?
    halt(env, status_code: 400, response: ({"error": "Snapshot #{snap_name} does not exist"}.to_json))
  end

  env.response.status_code = 200

  snap.to_json
end
