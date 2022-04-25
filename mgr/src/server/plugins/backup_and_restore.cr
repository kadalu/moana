require "moana_types"
require "file_utils"
require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/backup" do |env|
  backupdir = String.from_json(env.request.body.not_nil!)

  Dir.mkdir_p backupdir

  # Copy /var/lib/kadalu/info file into $(backupdir), only if it exists.
  begin
    FileUtils.cp("/var/lib/kadalu/info", backupdir)
  rescue File::NotFoundError
    halt(env, status_code: 403, response: ({"error": "Info file not found to backup"}.to_json))
  end

  Datastore.backup(backupdir)

  # Create a tar file with info, kadalu.db as contents and remove non-tar files.
  system "cd #{backupdir} && tar -czf kadalu_backup.tar.gz -C #{backupdir} . | bash"
  system "cd #{backupdir} && ls | grep -P '[^.tar.gz]$' | xargs -d'\n' rm"

  env.response.status_code = 204
end

post "/api/v1/restore" do |env|
  # The target path is a '.tar.gz' file with info metadata and kadalu.db as contents.
  targetpath = String.from_json(env.request.body.not_nil!)

  target_file_name = targetpath.split("/").pop

  FileUtils.cp(targetpath, "/tmp/#{target_file_name}")

  system "cd /tmp && tar -xf #{target_file_name}"

  FileUtils.touch("/var/lib/kadalu/mgr")

  FileUtils.cp("/tmp/info", "/var/lib/kadalu/info")

  Datastore.restore("/tmp/kadalu_backup.db")

  env.response.status_code = 204
end
