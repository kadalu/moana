require "./helpers"

struct UserArgs
  property username = "", password = "", name = "", pool_name = "", volume_name = "", role_name = "",
    current_password = "", new_password = ""
end

class Args
  property user_args = UserArgs.new
end

def prompt(label)
  print "#{label}: "
  value = (STDIN.noecho &.gets.try &.chomp).not_nil!
  puts
  value
end

def validated_username(args)
  username = args.pos_args.size > 0 ? args.pos_args[0] : ""
  command_error "Username is required" if username == ""

  username
end

command "user.create", "Create a Kadalu Storage User" do |parser, args|
  parser.banner = "Usage: kadalu user create USERNAME [arguments]"
  parser.on("-p PASSWORD", "--password=PASSWORD", "User Password") do |password|
    args.user_args.password = password
  end
  parser.on("-n NAME", "--name=NAME", "User Name") do |name|
    args.user_args.name = name
  end

  parser.on("--pool=POOL_NAME", "Storage Pool Name") do |name|
    args.user_args.pool_name = name
  end

  parser.on("--volume=VOLUME_NAME", "Volume Name") do |name|
    args.user_args.volume_name = name
  end

  parser.on("--role=ROLE_NAME", "Role Name (admin,maintainer,viewer,client)") do |name|
    args.user_args.role_name = name
  end
end

handler "user.create" do |args|
  args.user_args.username = validated_username(args)

  if args.user_args.username == ""
    command_error "Username is required"
  end

  if args.user_args.password.strip == ""
    args.user_args.password = prompt("Password")
  end

  api_call(args, "Failed to create the User") do |client|
    user = client.create_user(args.user_args.username, args.user_args.name, args.user_args.password)
    puts "User #{user.username} created successfully"
  end
end

command "login", "Login to Kadalu Storage" do |parser, args|
  parser.banner = "Usage: kadalu login USERNAME [arguments]"
  parser.on("-p PASSWORD", "--password=PASSWORD", "User Password") do |password|
    args.user_args.password = password
  end
end

handler "login" do |args|
  args.user_args.username = validated_username(args)

  if args.user_args.password.strip == ""
    args.user_args.password = prompt("Password")
  end

  # TODO: Handle if user is already logged in(If token_file exists)

  api_call(args, "Failed to Login") do |client|
    api_key = client.login(args.user_args.username, args.user_args.password)
    token_file = session_file
    Dir.mkdir_p(token_file.parent)
    File.write(token_file, api_key.to_json)
    puts "Login successful. Details saved in `#{token_file}`. Delete this file or run `kadalu logout` command to delete the session."
  end
end

command "logout", "Logout from Kadalu Storage" do |parser, _|
  parser.banner = "Usage: kadalu logout"
end

handler "logout" do |args|
  api_call(args, "Failed to Logout") do |client|
    next unless File.exists?(session_file)

    client.logout
    File.delete(session_file)
    puts
  end
end

# command "user.delete", "Delete a Kadalu Storage User" do |parser, _|
#   parser.banner = "Usage: kadalu user delete USERNAME"
# end

# handler "user.delete" do |args|
# end

# command "user.password", "Update Kadalu Storage User Password" do |parser, args|
#   parser.banner = "Usage: kadalu user password USERNAME [arguments]"
#   parser.on("-c PASSWORD", "--current-password=PASSWORD", "Current Password") do |password|
#     args.user_args.current_password = password
#   end
#   parser.on("-p PASSWORD", "--new-password=PASSWORD", "New Password") do |password|
#     args.user_args.new_password = password
#   end
# end

# handler "user.password" do |args|
#   if args.user_args.current_password.strip == ""
#     args.user_args.current_password = prompt("Current Password")
#   end
#   if args.user_args.new_password.strip == ""
#     args.user_args.new_password = prompt("New Password")
#   end
# end

# command "user.list", "List of Kadalu Storage Users" do |parser, args|
#   parser.banner = "Usage: kadalu user list"
# end

# handler "user.list" do |args|
# end

# command "role.add", "Add role to a Kadalu Storage User" do |parser, args|
#   parser.banner = "Usage: kadalu role add USERNAME ROLE [arguments]"
#   parser.on("--pool=POOL_NAME", "Storage Pool Name") do |name|
#     args.user_args.pool_name = name
#   end

#   parser.on("--volume=VOLUME_NAME", "Volume Name") do |name|
#     args.user_args.volume_name = name
#   end
# end

# handler "role.add" do |args|
# end

# command "role.remove", "Remove a role of a Kadalu Storage User" do |parser, args|
#   parser.banner = "Usage: kadalu role remove USERNAME ROLE [arguments]"
#   parser.on("--pool=POOL_NAME", "Storage Pool Name") do |name|
#     args.user_args.pool_name = name
#   end

#   parser.on("--volume=VOLUME_NAME", "Volume Name") do |name|
#     args.user_args.volume_name = name
#   end
# end

# handler "role.remove" do |args|
# end

# command "role.list", "List of Kadalu Storage Roles" do |parser, args|
#   parser.banner = "Usage: kadalu role list [arguments]"

#   parser.on("--username=USERNAME", "Storage Pool Username") do |name|
#     args.user_args.username = name
#   end

#   parser.on("--pool=POOL_NAME", "Storage Pool Name") do |name|
#     args.user_args.pool_name = name
#   end

#   parser.on("--volume=VOLUME_NAME", "Volume Name") do |name|
#     args.user_args.volume_name = name
#   end
# end

# handler "role.list" do |args|
# end

# command "api-key.create", "Create a Kadalu Storage API key" do |parser, _|
#   parser.banner = "Usage: kadalu api-key create NAME [arguments]"
# end

# handler "api-key.create" do |args|
# end

# command "api-key.delete", "Delete the Kadalu Storage API key" do |parser, _|
#   parser.banner = "Usage: kadalu api-key delete NAME [arguments]"
# end

# handler "api-key.delete" do |args|
# end

command "api-key.list", "List Kadalu Storage API keys" do |parser, _|
  parser.banner = "Usage: kadalu api-key list"
end

handler "api-key.list" do |args|
  api_call(args, "Failed to get the list of API Keys") do |client|
    api_keys = client.api_keys

    table = CliTable.new(3)
    table.header("ID", "token", "Name")

    api_keys.each do |api_key|
      table.record(api_key.id, api_key.token, api_key.name)
    end

    table.render
  end
end
