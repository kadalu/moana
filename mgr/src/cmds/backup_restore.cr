require "./helpers"

command "backup", "Set the kadalu backup directory" do |parser, _|
  parser.banner = "Usage: kadalu backup [arguments]"
end

handler "backup" do |args|
  backupdir = args.pos_args[0]
  api_call(args, "Failed to set the backup dir") do |client|
    puts typeof(backupdir)

    response = client.backup(backupdir)

    puts "in cmd", response

    # handle_json_output(pool, args)
  end
end

command "restore", "Restore kadalu storage by specifying target-path" do |parser, _|
  parser.banner = "Usage: kadalu restore [arguments]"
end

handler "restore" do |args|
  targetpath = args.pos_args[0]
  api_call(args, "Failed to restore kadalu storage") do |client|
    puts typeof(targetpath)

    response = client.restore(targetpath)

    puts "in cmd", response

    # handle_json_output(pool, args)
  end
end
