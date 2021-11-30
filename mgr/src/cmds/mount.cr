require "./helpers"
require "./mount_script"

MOUNT_BANNER = "
Usage: kadalu mount SERVER:/CLUSTER/VOLUME MOUNT_PATH [arguments]
       kadalu mount VOLFILE_PATH MOUNT_PATH [arguments]
       kadalu mount SERVER:/CLUSTER/VOLUME@SNAPNAME MOUNT_PATH [arguments]
       kadalu mount SERVER:/CLUSTER/VOLUME/SUBDIR MOUNT_PATH [arguments]
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

  MountKadalu.run(volume, mount_path, args.mount_args.options)
end
