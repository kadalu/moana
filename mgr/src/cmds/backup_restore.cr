require "./helpers"

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

  api_call(args, "Failed to restore kadalu storage") do |client|
    client.restore(backup_name)
    handle_json_output(nil, args)
  end
end
