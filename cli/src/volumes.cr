require "moana_types"

require "./helpers"

struct VolumeCreateArgs < Args
  property name : String = "",
           replica_count : Int32 = 1,
           disperse_count : Int32 = 1,
           brick_fs : String = "dir",
           fs_opts : String = "",
           use_lvm = false,
           size : UInt64 = 0,
           start = false,
           options = {} of String => String,
                           option_names = [] of String,
                                                bricks = [] of String

  def pos_args(args : Array(String))
    if args.size < 2
      STDERR.puts "Volume name or bricks are not specified"
      exit 1
    end
    @name = args[0]
    # Except first argument, all other arguments are Bricks
    @bricks = args[1 .. -1]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    req = MoanaTypes::VolumeCreateRequest.new
    req.name = @name
    req.brick_fs = @brick_fs
    req.fs_opts = @fs_opts
    req.replica_count = @replica_count
    req.disperse_count = @disperse_count
    req.start = @start
    req.bricks = prepare_bricks_list(cluster_id, @bricks, @brick_fs)
    req.cluster_id = cluster_id

    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      task = cluster.volume_create(req)
      puts "Volume creation request sent successfully."
      puts "Task ID: #{task.id}"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end

end

struct VolumeStartArgs < Args
  property name = ""

  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Volume name not specified"
      exit 1
    end
    @name = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
    start_stop_volume(gflags, @cluster_name, @name, "start")
  end
end

struct VolumeStopArgs < Args
  property name = ""

  def pos_args(args : Array(String))
    if args.size < 1
      STDERR.puts "Volume name not specified"
      exit 1
    end
    @name = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
    start_stop_volume(gflags, @cluster_name, @name, "stop")
  end
end

struct VolumeListArgs < Args
  property name = ""

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      volume_data = cluster.volumes
      if volume_data
        printf("%-36s  %-15s %-15s %s\n", "ID", "Name", "Type", "State")
      end
      volume_data.each do |volume|
        if @name == "" || volume.id == @name || volume.name == @name
          printf("%-36s  %-15s %-15s %-s\n",volume.id, volume.name, volume.type, volume.state)
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
      exit 1
    end
  end
end

struct VolumeInfoArgs < Args
  property name = ""

  
  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
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
      STDERR.puts ex.status_code
      exit 1
    end
  end
end

struct VolumeDeleteArgs < Args
  property name = ""

  def handle(gflags : Gflags)
  end
end

struct VolumeSetArgs < Args
  property name : String = "",
           options = {} of String => String

  def pos_args
    if args.size < 3
      STDERR.puts "Volume name and options are not specified"
      exit 1
    end
    if (args.size - 1).remainder(2) != 0
      STDERR.puts "Options pair not matching"
      exit 1
    end

    @name = args[0]
    # Except first argument, all other arguments are Option pairs
    args[1 .. -1].each_slice(2) do |opt|
      options[opt[0]] = opt[1]
    end

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
  end
end

struct VolumeResetArgs < Args
  property name : String = "",
           option_names = [] of String

  def pos_args
    if args.size < 2
      STDERR.puts "Volume name and option names are not specified"
      exit 1
    end

    @name = args[0]
    # Except first argument, all other arguments are Option names
    @option_names = args[1 .. -1]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
  end
end

class MoanaCommands
  def volume_commands(parser)
    parser.on("volume", "Manage Kadalu Storage Volumes") do
      parser.banner = "Usage: moana volume <subcommand> [arguments]"
      parser.on("list", "List Kadalu Storage Volumes") do
        args = VolumeListArgs.new
        parser.banner = "Usage: moana volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| args.name = name }

        @args = args
      end

      parser.on("info", "Kadalu Storage Volumes Info") do
        args = VolumeInfoArgs.new
        parser.banner = "Usage: moana volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| args.name = name }

        @args = args
      end

      parser.on("start", "Kadalu Storage Volumes Start") do
        args = VolumeStartArgs.new
        parser.banner = "Usage: moana volume start NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end

      parser.on("stop", "Kadalu Storage Volumes Stop") do
        args = VolumeStopArgs.new
        parser.banner = "Usage: moana volume stop NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end

      parser.on("create", "Create Kadalu Storage Volume") do
        args = VolumeCreateArgs.new

        parser.banner = "Usage: moana volume create NAME BRICKS [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("--replica-count=COUNT", "Replica Count") { |cnt| args.replica_count = cnt.to_i }
        parser.on("--disperse-count=COUNT", "Disperse Count") { |cnt| args.disperse_count = cnt.to_i }
        parser.on("--brick-fs=FS", "Brick Filesystem") do |fs|
          if !["zfs", "xfs", "ext4", "dir"].includes?(fs)
            STDERR.puts "Unsupported Brick File system. Available options: zfs, xfs, ext4, dir"
            exit 1
          end
          args.brick_fs = fs
        end

        parser.on("--xfs-opts", "XFS Options to use while creating xfs bricks (Only applicable if `--brick-fs=xfs`)") do |opts|
          args.fs_opts = opts
        end

        parser.on("--zfs-opts", "ZFS Options to use while creating zfs bricks (Only applicable if `--brick-fs=zfs`)") do |opts|
          args.fs_opts = opts
        end

        parser.on("--ext4-opts", "ext4 Options to use while creating ext4 bricks (Only applicable if `--brick-fs=ext4`)") do |opts|
          args.fs_opts = opts
        end

        parser.on("--use-lvm", "Use LVM for creating Brick Partition (Only applicable if `--brick-type=xfs|ext4`)") do
          args.use_lvm = true
        end

        parser.on("--size", "Volume Size. Only applicable if `--use-lvm` is used") do |size|
          args.size = size.to_u64
        end

        parser.on("--start", "Start Volume after Create") { args.start = true }

        @args = args
      end

      parser.on("delete", "Delete Kadalu Storage Volume") do
        args = VolumeDeleteArgs.new
        parser.banner = "Usage: moana volume delete NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end

      parser.on("set", "Set Kadalu Storage Volume Options") do
        args = VolumeSetArgs.new
        parser.banner = "Usage: moana volume set OPTNAME1 OPTVALUE1 ... [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end

      parser.on("reset", "Reset Kadalu Storage Volume Options") do
        args = VolumeResetArgs.new
        parser.banner = "Usage: moana volume reset OPTNAME1 ... [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end
    end
  end
end
