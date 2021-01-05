require "./helpers"
require "moana_client"
require "moana_types"

struct RegisterCommand < Command
  def pos_args(args : Array(String))
    if args.size < 2
      STDERR.puts "Name and Email are not specified"
      exit 1
    end

    @args.user.name = args[0]
    @args.user.email = args[1]
  end

  def handle
    print "Enter password: "
    password = STDIN.noecho &.gets.try &.chomp
    if password.nil?
      STDERR.puts "Password is required"
      exit 1
    else
      @args.user.password = password
    end

    puts

    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      user = client.create_user(@args.user.name, @args.user.email, @args.user.password)
      puts "User registered successfully."
      puts "ID: #{user.id}"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct LoginCommand < Command
  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Email is not specified"
      exit 1
    end

    @args.user.email = args[0]
  end

  def handle
    print "Enter password: "
    password = STDIN.noecho &.gets.try &.chomp
    if password.nil?
      STDERR.puts "Password is required"
      exit 1
    else
      @args.user.password = password
    end

    puts

    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      app = client.user(@args.user.email).create_app(@args.user.password)
      puts "Successfully logged in to Kadalu Storage Server."
      puts "App ID: #{app.id}"
      filename = Path.home.join(".kadalu", "app.json")
      Dir.mkdir_p(Path[filename].parent)
      File.write(filename, app.to_json)
      puts "Token saved to `~/.kadalu/app.json` Run `#{COMMAND} logout` "
      puts "to logout from the Server or delete the `~/.kadalu/app.json` file."
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct LogoutCommand < Command
  def pos_args(args : Array(String))
  end

  def handle
    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      filename = Path.home.join(".kadalu", "app.json")
      app = MoanaTypes::App.from_json(File.read(filename))
      app_id = @args.app.id == "" ? app.id : @args.app.id
      client.user(app.user_id).app(app_id).delete
      File.delete(filename)
      puts "Successfully logged out from the Kadalu Storage Server."
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct AppsCommand < Command
  def pos_args(args : Array(String))
  end

  def handle
    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      filename = Path.home.join(".kadalu", "app.json")
      app = MoanaTypes::App.from_json(File.read(filename))
      apps = client.user(app.user_id).apps
      puts apps
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct RoleAddCommand < Command
  def pos_args(args : Array(String))
    if args.size < 2
      STDERR.puts "Email and Role name are not specified"
      exit 1
    end

    @args.user.email = args[0]
    @args.user.role = args[1]

    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      role = client.add_role(@args.user.name, cluster_id, @args.volume.name, @args.user.role)
      puts "Successfully set Role"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct RoleDeleteCommand < Command
  def pos_args(args : Array(String))
    if args.size < 2
      STDERR.puts "Email and Role name are not specified"
      exit 1
    end

    @args.user.email = args[0]
    @args.user.role = args[1]

    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      role = client.role(@args.user.email, cluster_id, @args.volume.name, @args.user.role).delete
      puts "Successfully deleted the Role"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

class MoanaCommands
  def register_commands(parser)
    parser.on("register", "Register #{PRODUCT} User") do
      parser.banner = "Usage: #{COMMAND} register <name> <email>"
      @command_type = CommandType::Register
    end
  end

  def login_commands(parser)
    parser.on("login", "Login to #{PRODUCT}") do
      parser.banner = "Usage: #{COMMAND} login <email>"
      @command_type = CommandType::Login
    end
  end

  def logout_commands(parser)
    parser.on("logout", "Logout from #{PRODUCT}") do
      parser.banner = "Usage: #{COMMAND} logout <email>"
      @command_type = CommandType::Logout
      parser.on("--app=APPID", "App ID") { |app_id| @args.app.id = app_id }
    end
  end

  def apps_commands(parser)
    parser.on("apps", "List of #{PRODUCT} apps") do
      parser.banner = "Usage: #{COMMAND} apps"
      @command_type = CommandType::Apps
    end
  end

  def role_commands(parser)
    parser.on("role", "Manage Roles") do
      parser.banner = "Usage: #{COMMAND} role <subcommand> [arguments]"
      parser.on("add", "Add Role") do
        @command_type = CommandType::RoleAdd
        parser.banner = "Usage: #{COMMAND} role add <email> <role> [arguments]"
        parser.on("-v VOLUME_ID", "--volume=VOLUME_ID", "Volume ID") { |volume_id| @args.volume.name = volume_id }
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
          @args.cluster.name = name
        end
      end

      parser.on("delete", "Delete Role") do
        @command_type = CommandType::RoleDelete
        parser.banner = "Usage: #{COMMAND} role delete <email> <role> [arguments]"
        parser.on("-v VOLUME_ID", "--volume=VOLUME_ID", "Volume ID") { |volume_id| @args.volume.name = volume_id }
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
          @args.cluster.name = name
        end
      end
    end
  end
end
