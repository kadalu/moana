require "moana_types"
require "file_utils"
require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/backups" do |env|
  data = Hash(String, String).from_json(env.request.body.not_nil!)
  backup_name = data["name"]?
  if backup_name.nil? || backup_name.strip == ""
    halt(env, status_code: 400, response: ({"error": "Invalid Backup name"}.to_json))
  end

  backup_dir = "#{GlobalConfig.workdir}/backups" + "/#{backup_name}"

  if Dir.exists?(backup_dir)
    halt(env, status_code: 400, response: ({"error": "Backup directory already exists"}.to_json))
  end

  Dir.mkdir_p backup_dir

  FileUtils.cp("#{GlobalConfig.workdir}/info", backup_dir) if File.exists?("#{GlobalConfig.workdir}/info")

  time = Time.utc.to_s("%Y/%m/%d %H:%M:%s")
  metadata = {"created_on": time}.to_json
  File.write("#{backup_dir}/meta.json", metadata)

  Datastore.backup(backup_dir)

  env.response.status_code = 200

  {"name": backup_name, "created_on": time}.to_json
end
