require "moana_types"
require "file_utils"
require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/backup" do |env|
  backup_name = String.from_json(env.request.body.not_nil!)

  backup_dir = "#{GlobalConfig.workdir}/backups" + "/#{backup_name}"

  if Dir.exists?(backup_dir)
    halt(env, status_code: 400, response: ({"error": "Backup directory already exists`"}.to_json))
  end

  Dir.mkdir_p backup_dir

  FileUtils.cp("#{GlobalConfig.workdir}/info", backup_dir) if File.exists?("#{GlobalConfig.workdir}/info")

  time = Time.utc.to_s("%Y/%m/%d %H:%M:%s")
  metadata = {"created_at": time}.to_json
  File.write("#{backup_dir}/meta.json", metadata)

  Datastore.backup(backup_dir)

  env.response.status_code = 204
end

post "/api/v1/restore" do |env|
  backup_name = String.from_json(env.request.body.not_nil!)

  backup_dir = "#{GlobalConfig.workdir}/backups/" + backup_name

  FileUtils.touch("#{GlobalConfig.workdir}/mgr") if !File.exists?("#{GlobalConfig.workdir}/mgr")

  Dir.mkdir_p "#{GlobalConfig.workdir}/meta" if !Dir.exists?("#{GlobalConfig.workdir}/meta")

  if !Dir.exists?(backup_dir)
    halt(env, status_code: 400, response: ({"error": "Backup directory does not exist"}.to_json))
  end

  FileUtils.cp("#{backup_dir}/info", "#{GlobalConfig.workdir}/info")

  Datastore.restore("#{backup_dir}/kadalu_backup.db")

  env.response.status_code = 204
end
