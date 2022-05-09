require "./helpers"
require "../server/datastore/*"
require "file_utils"

command "backup", "Take backup of Kadalu Storage Configurations" do |parser, _|
  parser.banner = "Usage: kadalu backup [arguments]"
end

handler "backup" do |args|
  if args.pos_args.size == 0
    STDERR.puts "Backup name cannot be empty"
    exit 1
  end

  backup_name = args.pos_args[0]

  api_call(args, "Failed to set the backup dir") do |client|
    response = client.backup(backup_name)
    handle_json_output(response, args)
    puts <<-STRING
    Backup #{backup_name} created Successfully! Upload or copy the files from
    `/var/lib/kadalu/backups/#{backup_name}` directory from the Manager node
    to the cloud or any other machines. To restore or recreate the Manager
    node, then download the backup copy from the cloud to
    `/var/lib/kadalu/backups/#{backup_name}` and run the restore command as below.

    kadalu restore #{backup_name}
    STRING
  end
end

command "restore", "Restore Kadalu Storage Configurations by specifying backup name" do |parser, _|
  parser.banner = "Usage: kadalu restore [arguments]"
end

handler "restore" do |args|
  if args.pos_args.size == 0
    STDERR.puts "Backup name cannot be empty"
    exit 1
  end

  backup_name = args.pos_args[0]

  if File.exists?("/var/lib/kadalu/meta/kadalu.db")
    next unless (args.script_mode || yes("Are you sure you want to overwrite Kadalu metadata?"))
  end

  workdir = "/var/lib/kadalu"
  backup_dir = "#{workdir}/backups/" + backup_name

  if !Dir.exists?(backup_dir)
    error_message = "Backup directory #{backup_dir} does not exist"
    handle_json_error(error_message, args)
    command_error(error_message)
  end

  FileUtils.touch("#{workdir}/mgr")

  Dir.mkdir_p "#{workdir}/meta"

  FileUtils.cp("#{backup_dir}/info", "#{workdir}/info")

  Datastore.restore_from("#{backup_dir}/kadalu_backup.db")

  handle_json_output(nil, args)
  puts <<-STRING
  Kadalu Storage setup restored from the backup #{backup_name} successfully!.
  Start the kadalu mgr process as below.

  kadalu mgr
  STRING
end
