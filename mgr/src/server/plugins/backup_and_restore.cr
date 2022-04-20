require "moana_types"
require "file_utils"
require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/backup" do |env|
  puts "hello"

  backupdir = String.from_json(env.request.body.not_nil!)
  info_file_path = "/var/lib/kadalu/info"

  puts "in backup plugins", backupdir

  # Copy /var/lib/kadalu/info file into $(backupdir) [if exists only!]

  Dir.mkdir_p backupdir

  begin
    FileUtils.cp("/var/lib/kadalu/info", backupdir)
  rescue File::NotFoundError
    puts "error"
    halt(env, status_code: 403, response: ({"error": "Info file not found to backup"}.to_json))
  end

  Datastore.backup(backupdir)

  # Create a tar file with info, kadalu.db as contents and remove non-tar files.
  system "cd #{backupdir} && tar -czvf kadalu_backup.tar.gz -C #{backupdir} ."
  system "cd #{backupdir} && ls | grep -P '[^.tar.gz]$' | xargs -d'\n' rm"

end
