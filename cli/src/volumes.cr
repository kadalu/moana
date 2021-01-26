require "moana_types"

require "./helpers"

struct VolumeCreateCommand < Command
  def pos_args(args : Array(String))
    if args.size < 2
      STDERR.puts "Volume name or bricks are not specified"
      exit 1
    end
    @args.volume.name = args[0]
    # Except first argument, all other arguments are Bricks
    @args.volume.bricks = args[1 .. -1]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    req = MoanaTypes::VolumeCreateRequest.new
    req.name = @args.volume.name
    req.brick_fs = @args.volume.brick_fs
    req.fs_opts = @args.volume.fs_opts
    req.replica_count = @args.volume.replica_count
    req.disperse_count = @args.volume.disperse_count
    req.start = @args.volume.start
    req.bricks = prepare_bricks_list(cluster_id, @args.volume.bricks, @args.volume.brick_fs)
    req.cluster_id = cluster_id

    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      task = cluster.create_volume(req)
      puts "Volume creation request sent successfully."
      puts "Task ID: #{task.id}"
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end

end

struct VolumeStartCommand < Command
  property name = ""

  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Volume name not specified"
      exit 1
    end
    @args.volume.name = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    start_stop_volume(@gflags, @args.cluster.name, @args.volume.name, "start")
  end
end

struct VolumeStopCommand < Command
  property name = ""

  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Volume name not specified"
      exit 1
    end
    @args.volume.name = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    start_stop_volume(@gflags, @args.cluster.name, @args.volume.name, "stop")
  end
end

struct VolumeListCommand < Command
  property name = ""

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      volume_data = cluster.volumes
      if volume_data.size > 0
        printf("%-36s  %-15s %-15s %s\n", "ID", "Name", "Type", "State")
      end
      volume_data.each do |volume|
        if @args.volume.name == "" || volume.id == @args.volume.name || volume.name == @args.volume.name
          printf("%-36s  %-15s %-15s %-s\n",volume.id, volume.name, volume.type, volume.state)
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

struct VolumeInfoCommand < Command
  property name = ""

  
  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      volume_data = cluster.volumes
      volume_data.each do |vol|
        puts "Name                    : #{vol.name}"
        puts "Type                    : #{vol.type}"
        puts "ID                      : #{vol.id}"
        puts "Status                  : #{vol.state}"
        puts "Number of Storage units : #{vol.subvols.size * vol.subvols[0].bricks.size}"
        vol.subvols.each_with_index do |subvol, sidx|
          subvol.bricks.each_with_index do |brick, idx|
            printf(
              "Storage Unit %-3s        : %s:%s (Port: %s)\n",
              idx+1,
              brick.node.hostname,
              brick.path,
              brick.port
            )
            puts
            puts
          end
        end
        puts "Options:" + (vol.options.size > 0 ? "" : " -")

        vol.options.each do |k, v|
          printf("    %20s: %s\n", k, v)
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

struct VolumeDeleteCommand < Command
  def handle
  end
end

struct VolumeSetCommand < Command
  def pos_args(args)
    if args.size < 3
      STDERR.puts "Volume name and options are not specified"
      exit 1
    end
    if (args.size - 1).remainder(2) != 0
      STDERR.puts "Options pair not matching"
      exit 1
    end

    puts "args #{args}"
    @args.volume.name = args[0]

    # Except first argument, all other arguments are Option pairs
    args[1 .. -1].each_slice(2) do |opt|
      @args.volume.options[opt[0]] = opt[1]
    end

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(gflags.kadalu_mgmt_server)

    begin
      volume_id = volume_id_from_name(client, cluster_id, @args.volume.name)
      volume = client.cluster(cluster_id).volume(volume_id)
      volume.set_options(@args.volume.options)
      puts "Volume options set successfully."
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

struct VolumeResetCommand < Command
  def pos_args(args)
    if args.size < 2
      STDERR.puts "Volume name and option names are not specified"
      exit 1
    end

    @args.volume.name = args[0]
    # Except first argument, all other arguments are Option names
    @args.volume.option_names = args[1 .. -1]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(gflags.kadalu_mgmt_server)

    begin
      volume_id = volume_id_from_name(client, cluster_id, @args.volume.name)
      volume = client.cluster(cluster_id).volume(volume_id)
      volume.reset_options(@args.volume.option_names)
      puts "Volume options reset successfully."
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

class MoanaCommands
  def volume_commands(parser)
    parser.on("volume", "Manage #{PRODUCT} Volumes") do
      parser.banner = "Usage: #{COMMAND} volume <subcommand> [arguments]"
      parser.on("list", "List #{PRODUCT} Volumes") do
        @command_type = CommandType::VolumeList
        parser.banner = "Usage: #{COMMAND} volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| @args.volume.name = name }
      end

      parser.on("info", "#{PRODUCT} Volumes Info") do
        @command_type = CommandType::VolumeInfo
        parser.banner = "Usage: #{COMMAND} volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| @args.volume.name = name }
      end

      parser.on("start", "#{PRODUCT} Volumes Start") do
        @command_type = CommandType::VolumeStart
        parser.banner = "Usage: #{COMMAND} volume start NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end

      parser.on("stop", "#{PRODUCT} Volumes Stop") do
        @command_type = CommandType::VolumeStop
        parser.banner = "Usage: #{COMMAND} volume stop NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end

      parser.on("create", "Create #{PRODUCT} Volume") do
        @command_type = CommandType::VolumeCreate

        parser.banner = "Usage: #{COMMAND} volume create NAME BRICKS [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("--replica-count=COUNT", "Replica Count") { |cnt| @args.volume.replica_count = cnt.to_i }
        parser.on("--disperse-count=COUNT", "Disperse Count") { |cnt| @args.volume.disperse_count = cnt.to_i }
        parser.on("--brick-fs=FS", "Brick Filesystem") do |fs|
          if !["zfs", "xfs", "ext4", "dir"].includes?(fs)
            STDERR.puts "Unsupported Brick File system. Available options: zfs, xfs, ext4, dir"
            exit 1
          end
          @args.volume.brick_fs = fs
        end

        parser.on("--xfs-opts", "XFS Options to use while creating xfs bricks (Only applicable if `--brick-fs=xfs`)") do |opts|
          @args.volume.fs_opts = opts
        end

        parser.on("--zfs-opts", "ZFS Options to use while creating zfs bricks (Only applicable if `--brick-fs=zfs`)") do |opts|
          @args.volume.fs_opts = opts
        end

        parser.on("--ext4-opts", "ext4 Options to use while creating ext4 bricks (Only applicable if `--brick-fs=ext4`)") do |opts|
          @args.volume.fs_opts = opts
        end

        parser.on("--use-lvm", "Use LVM for creating Brick Partition (Only applicable if `--brick-type=xfs|ext4`)") do
          @args.volume.use_lvm = true
        end

        parser.on("--size", "Volume Size. Only applicable if `--use-lvm` is used") do |size|
          @args.volume.size = size.to_u64
        end

        parser.on("--start", "Start Volume after Create") { @args.volume.start = true }
      end

      parser.on("delete", "Delete #{PRODUCT} Volume") do
        @command_type = CommandType::VolumeDelete
        parser.banner = "Usage: #{COMMAND} volume delete NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end

      parser.on("set", "Set #{PRODUCT} Volume Options") do
        @command_type = CommandType::VolumeSet
        parser.banner = "Usage: #{COMMAND} volume set VOLNAME OPTNAME1 OPTVALUE1 ... [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end

      parser.on("reset", "Reset #{PRODUCT} Volume Options") do
        @command_type = CommandType::VolumeReset
        parser.banner = "Usage: #{COMMAND} volume reset VOLNAME OPTNAME1 ... [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end
    end
  end
end
