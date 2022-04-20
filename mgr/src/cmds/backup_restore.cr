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

    #handle_json_output(pool, args)
  end
end
