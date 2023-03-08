require "./helpers"
require "./mount_script"

MOUNT_BANNER = %q[
Usage: Use `kadalu mount` or `mount -t kadalu` command to mount the
Kadalu Storage Pool.

    mount -t kadalu MGR_URL:/POOL_NAME MOUNT_PATH [arguments]

    OR

    kadalu mount MGR_URL:/POOL_NAME MOUNT_PATH [arguments]

Examples:

    # Specify Storage manager URL. Login Credentials
    # from the Session file
    kadalu mount http://server1:3000:/pool1 /mnt/pool1

    # Take Storage manager URL from ENV, Login Credentials
    # from the Session file
    kadalu mount /pool1 /mnt/pool1

    # Login Credentials - Password Prompt
    kadalu mount -o "username=admin" http://server1:3000:/pool1 /mnt/pool1

    # Login Credentials
    kadalu mount -o "username=admin,password=secret" http://server1:3000:/pool1 /mnt/pool1
    kadalu mount -o "username=admin,password_file=/root/kadalu_secret" http://server1:3000:/pool1 /mnt/pool1

    # Login using API Key
    kadalu mount -o "username=admin,user_id=ee65360a-e763-459d-b898-c67756a112e0,api_key=ce1d97f.." \
        http://server1:3000:/pool1 /mnt/pool1

    # Use Volfile Server or Volfile servers option and skip Mgr URL
    kadalu mount -o "volfile-server=server1:49252" /pool1 /mnt/pool1
    kadalu mount -o "volfile-servers=server1:49252 server2:49252 server3:49253" /pool1 /mnt/pool1

    # Specify Storage Unit URL
    kadalu mount server1:49252:/pool1 /mnt/pool1

    # Custom Volfile
    kadalu mount /root/custom_volfiles/awesome_config.vol /mnt/pool1

    # Snapshot Mount
    kadalu mount http://server1:3000:/pool1@snap1 /mnt/pool1_snap1

    # Subdirectory mount
    kadalu mount http://server1:3000:/pool1/d1 /mnt/pool1_d1
]

class MountArgs
  property options = ""
end

class Args
  property mount_args = MountArgs.new
end

command "mount", "Mount the Kadalu Storage Pool" do |parser, args|
  parser.banner = MOUNT_BANNER
  parser.on("-o OPTIONS", "--options=OPTIONS", "Mount Options(comma seperated)") do |opts|
    args.mount_args.options = opts
  end
  parser.on("-V", "Show Version information") do
    puts "Kadalu Storage Mount Script - #{VERSION}"
    exit
  end
end

struct MountMetaOptions
  property volfile_servers = [] of String, username = "",
    password = "", password_file = "", user_id = "", api_key = ""

  def initialize
  end
end

def parse_mount_meta_options(raw_options)
  meta_opts = MountMetaOptions.new
  raw_options.strip.split(",").each do |opt|
    next if opt.strip == ""

    opt_name, _, opt_value = opt.strip.partition("=")

    case opt_name.strip
    when "user-id"
      meta_opts.user_id = opt_value.strip
    when "username"
      meta_opts.username = opt_value.strip
    when "password"
      meta_opts.password = opt_value.strip
    when "password-file"
      meta_opts.password_file = opt_value.strip
    when "api-key"
      meta_opts.api_key = opt_value.strip
    when "volfile-server", "volfile-servers"
      opt_value.strip.split(" ").each do |server|
        meta_opts.volfile_servers << server.strip
      end
    end
  end

  meta_opts
end

handler "mount" do |args|
  command_error "ERROR: Invalid arguments" if args.pos_args.size != 2

  pool_data, mount_path = args.pos_args
  mount_path = mount_path.rstrip("/")

  hostname, pool_name, volfile_path = MountKadalu.pool_details(pool_data)
  meta_opts = parse_mount_meta_options(args.mount_args.options)

  mgr_url_given = (hostname.starts_with?("http://") || hostname.starts_with?("https://"))

  # If volfile_servers are not given and hostname is empty then try to use
  # KADALU_URL env variable.
  mgr_url_from_env = hostname == "" && meta_opts.volfile_servers.size == 0

  # TODO: To support login credentials via options, parse the mount options
  # and login or use the API key as required. Till this is implemented,
  # run `kadalu login` and then run the mount command.

  # If manager URL is given, then fetch the Pool info and extract the
  # Storage unit's hostname and Port details.
  if volfile_path == "" && (mgr_url_given || mgr_url_from_env)
    args.url = hostname if mgr_url_given

    api_call(args, "Failed to get Pool info") do |client|
      pool = client.pool(pool_name).get

      # Extract all Storage unit hostname and Ports
      # and add as volfile-servers
      servers = [] of String
      pool.distribute_groups.each do |grp|
        grp.storage_units.each do |storage_unit|
          servers << "#{storage_unit.node.name}:#{storage_unit.port}"
        end
      end
      if args.mount_args.options == ""
        args.mount_args.options = "volfile-servers=#{servers.uniq.join(" ")}"
      else
        args.mount_args.options += ",volfile-servers=#{servers.uniq.join(" ")}"
      end
    end
  end

  MountKadalu.run(hostname, pool_name, volfile_path, mount_path, args.mount_args.options)
end
