require "./helpers"
require "./mount_script"

MOUNT_BANNER = "
Usage: kadalu mount SERVER:/POOL/VOLUME MOUNT_PATH [arguments]
       kadalu mount VOLFILE_PATH MOUNT_PATH [arguments]
       kadalu mount SERVER:/POOL/VOLUME@SNAPNAME MOUNT_PATH [arguments]
       kadalu mount SERVER:/POOL/VOLUME/SUBDIR MOUNT_PATH [arguments]
"

struct MountArgs
  property options = ""
end

class Args
  property mount_args = MountArgs.new
end

command "mount", "Mount the Kadalu Storage Volume" do |parser, args|
  parser.banner = MOUNT_BANNER
  parser.on("-o OPTIONS", "--options=OPTIONS", "Mount Options(comma seperated)") do |opts|
    args.mount_args.options = opts
  end
  parser.on("-V", "Show Version information") do
    puts "Kadalu Storage Mount Script - #{VERSION}"
    exit
  end
end

handler "mount" do |args|
  command_error "ERROR: Invalid arguments" if args.pos_args.size != 2

  volume, mount_path = args.pos_args
  mount_path = mount_path.rstrip("/")

  hostname, pool_name, volume_name, volfile_path = MountKadalu.volume_details(volume)

  # Download the Client Volfile from the Server
  if volfile_path == ""
    api_call(args, "Failed to generate the Volfile") do |client|
      volfile = client.pool(pool_name).volume(volume_name).get_volfile("client")

      volfile_dir = Path.new(GlobalConfig.workdir, "volfiles")
      volfile_path = Path.new(volfile_dir, "client-#{pool_name}-#{volume_name}.vol").to_s
      Dir.mkdir_p(volfile_dir)
      File.write(volfile_path, volfile.content)
    end
  end

  MountKadalu.run(hostname, pool_name, volume_name, volfile_path, mount_path, args.mount_args.options)
end
