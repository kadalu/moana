require "./helpers"

command "backup", "Set the kadalu backup directory" do |parser, _|
  parser.banner = "Usage: kadalu backup [arguments]"
end

handler "backup" do |args|
  backupdir = args.pos_args[0]

  api_call(args, "Failed to set the backup dir") do |client|
    client.backup(backupdir)
  end
end

command "restore", "Restore kadalu storage by specifying target-path" do |parser, _|
  parser.banner = "Usage: kadalu restore [arguments]"
end

handler "restore" do |args|
  targetpath = args.pos_args[0]

  if File.exists?("/var/lib/kadalu/meta/kadalu.db")
    next unless (args.script_mode || yes("Are you sure you want to overwrite Kadalu metadata?"))
  end

  api_call(args, "Failed to restore kadalu storage") do |client|
    client.restore(targetpath)
    handle_json_output(nil, args)
  end
end
