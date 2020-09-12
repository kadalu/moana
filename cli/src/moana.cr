require "option_parser"

require "./clusters"
require "./nodes"
require "./volumes"

enum SubCommands
  Unknown
  ClusterCreate
  ClusterUpdate
  ClusterList
  ClusterDelete

  NodeJoin
  NodeUpdate
  NodeList
  NodeLeave

  VolumeCreate
  VolumeList
  VolumeInfo
  VolumeDelete
end

struct Gflags
  property moana_url

  def initialize(@moana_url : String)
  end
end

struct ClusterArgs
  property name, newname

  def initialize(@name = "", @newname = "")
  end
end

struct NodeArgs
  property name, newname, cluster_name, endpoint

  def initialize(@name = "", @newname = "", @cluster_name = "", @endpoint = "")
  end
end

struct VolumeArgs
  property name, cluster_name, replica_count, disperse_count, brick_fs, xfs_opts, zfs_opts, ext4_opts, use_lvm, size, start, bricks

  def initialize(@name = "", @cluster_name = "", @replica_count = 1, @disperse_count = 1, @brick_fs = "", @xfs_opts = "", @zfs_opts = "", @ext4_opts = "", @use_lvm = false, @size : UInt64 = 0, @start = false, @bricks = [] of String)
  end
end

class MoanaCommands
  @cluster_args = ClusterArgs.new
  @node_args = NodeArgs.new
  @volume_args = VolumeArgs.new
  @subcmd = SubCommands::Unknown
  @pos_args = [] of String
  @gflags = Gflags.new ENV.fetch("MOANA_URL", "")

  def cluster_commands(parser)
    parser.on("cluster", "Manage Moana Clusters") do
      parser.banner = "Usage: moana cluster <subcommand> [arguments]"
      parser.on("list", "List Moana Clusters") do
        @subcmd = SubCommands::ClusterList
        parser.banner = "Usage: moana cluster list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @cluster_args.name = name }
      end

      parser.on("create", "Create Moana Cluster") do
        @subcmd = SubCommands::ClusterCreate
        parser.banner = "Usage: moana cluster create NAME [arguments]"
      end

      parser.on("delete", "Delete Moana Cluster") do
        @subcmd = SubCommands::ClusterDelete
        parser.banner = "Usage: moana cluster delete NAME [arguments]"
      end

      parser.on("update", "Update Moana Cluster") do
        @subcmd = SubCommands::ClusterUpdate
        parser.banner = "Usage: moana cluster update NEWNAME [arguments]"
        parser.on("-c NAME", "Cluster name") { |name| @cluster_args.name = name }
      end
    end
  end

  def node_commands(parser)
    parser.on("node", "Manage Moana Nodes") do
      parser.banner = "Usage: moana node <subcommand> [arguments]"
      parser.on("list", "List Moana Nodes") do
        @subcmd = SubCommands::NodeList
        parser.banner = "Usage: moana node list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @node_args.cluster_name = name }
        parser.on("-n NAME", "--node=NAME", "Node name") { |name| @node_args.name = name }
      end

      parser.on("join", "Join to a Moana Cluster") do
        @subcmd = SubCommands::NodeJoin
        parser.banner = "Usage: moana node join NAME ENDPOINT [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @node_args.cluster_name = name }
      end

      parser.on("leave", "Leave from a Moana Cluster") do
        @subcmd = SubCommands::NodeLeave
        parser.banner = "Usage: moana node leave NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @node_args.cluster_name = name }
      end

      parser.on("update", "Update Moana Node") do
        @subcmd = SubCommands::NodeUpdate
        parser.banner = "Usage: moana node update [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @node_args.cluster_name = name }
        parser.on("-n NAME", "Node name") { |name| @node_args.name = name }
        parser.on("--new-name NAME", "New Node name") { |newname| @node_args.newname = newname }
        parser.on("--endpoint NAME", "Node Endpoint") { |endpoint| @node_args.endpoint = endpoint }
      end
    end
  end

  def volume_commands(parser)
    parser.on("volume", "Manage Kadalu Storage Volumes") do
      parser.banner = "Usage: moana volume <subcommand> [arguments]"
      parser.on("list", "List Kadalu Storage Volumes") do
        @subcmd = SubCommands::VolumeList
        parser.banner = "Usage: moana volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @volume_args.cluster_name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| @volume_args.name = name }
      end

      parser.on("info", "Kadalu Storage Volumes Info") do
        @subcmd = SubCommands::VolumeInfo
        parser.banner = "Usage: moana volume list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @volume_args.cluster_name = name }
        parser.on("-n NAME", "--volume=NAME", "Volume name") { |name| @volume_args.name = name }
      end

      parser.on("create", "Create Kadalu Storage Volume") do
        @subcmd = SubCommands::VolumeCreate
        parser.banner = "Usage: moana volume create NAME BRICKS [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @volume_args.cluster_name = name }
        parser.on("--replica-count=COUNT", "Replica Count") { |cnt| @volume_args.replica_count = cnt.to_i }
        parser.on("--disperse-count=COUNT", "Disperse Count") { |cnt| @volume_args.disperse_count = cnt.to_i }
        parser.on("--brick-fs=FS", "Brick Filesystem") do |fs|
          if !["zfs", "xfs", "ext4", "dir"].includes?(fs)
            STDERR.puts "Unsupported Brick File system. Available options: zfs, xfs, ext4, dir"
            exit 1
          end
          @volume_args.brick_fs = fs
        end

        parser.on("--xfs-opts", "XFS Options to use while creating xfs bricks (Only applicable if `--brick-fs=xfs`)") do |opts|
          @volume_args.xfs_opts = opts
        end

        parser.on("--zfs-opts", "ZFS Options to use while creating zfs bricks (Only applicable if `--brick-fs=zfs`)") do |opts|
          @volume_args.zfs_opts = opts
        end

        parser.on("--ext4-opts", "ext4 Options to use while creating ext4 bricks (Only applicable if `--brick-fs=ext4`)") do |opts|
          @volume_args.ext4_opts = opts
        end

        parser.on("--use-lvm", "Use LVM for creating Brick Partition (Only applicable if `--brick-type=xfs|ext4`)") do
          @volume_args.use_lvm = true
        end

        parser.on("--size", "Volume Size. Only applicable if `--use-lvm` is used") do |size|
          @volume_args.size = size.to_u64
        end

        parser.on("--start", "Start Volume after Create") { @volume_args.start = true }
      end

      parser.on("delete", "Delete Kadalu Storage Volume") do
        @subcmd = SubCommands::VolumeDelete
        parser.banner = "Usage: moana volume delete NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @volume_args.cluster_name = name }
      end
    end
  end


  def parse
    parser = OptionParser.new do |parser|
      parser.banner = "Usage: moana <subcommand> [arguments]"

      cluster_commands parser
      node_commands parser
      volume_commands parser

      #parser.on("-v", "--verbose", "Enabled servose output") { verbose = true }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end

      parser.unknown_args do |args|
        @pos_args = args
      end

      parser.invalid_option do |flag|
        STDERR.puts "Invalid Option: #{flag}"
        exit 1
      end

      parser.missing_option do |flag|
        STDERR.puts "Missing Option: #{flag}"
        exit 1
      end

      parser.parse

      if @gflags.moana_url == ""
        STDERR.puts "MOANA_URL environment variable is not set"
        exit 1
      end
    end

    handle
  end

  def cluster_name_validate(args)
    if args.size != 1
      STDERR.puts "Cluster name is not specified"
      exit 1
    end
  end

  def cluster_name_required(args)
    if args.cluster_name == ""
      STDERR.puts "Cluster name or ID not specified"
      exit 1
    end
  end

  def handle
    # Route each sub commands
    case @subcmd
    when SubCommands::ClusterList
      show_clusters(@gflags, @cluster_args)

    when SubCommands::ClusterCreate
      cluster_name_validate(@pos_args)
      @cluster_args.name = @pos_args[0]
      create_cluster(@gflags, @cluster_args)

    when SubCommands::ClusterUpdate
      cluster_name_validate(@pos_args)
      @cluster_args.newname = @pos_args[0]
      update_cluster(@gflags, @cluster_args)

    when SubCommands::ClusterDelete
      cluster_name_validate(@pos_args)
      @cluster_args.name = @pos_args[0]
      delete_cluster(@gflags, @cluster_args)

    when SubCommands::NodeList
      cluster_name_required(@node_args)
      show_nodes(@gflags, @node_args)

    when SubCommands::NodeJoin
      if @pos_args.size != 2
        STDERR.puts "Nodename and Endpoint not specified"
        exit 1
      end
      cluster_name_required(@node_args)
      @node_args.name = @pos_args[0]
      @node_args.endpoint = @pos_args[1]
      create_node(@gflags, @node_args)

    when SubCommands::NodeUpdate
      cluster_name_required(@node_args)
      update_node(@gflags, @node_args)

    when SubCommands::NodeLeave
      if @pos_args.size != 1
        STDERR.puts "Nodename is not specified"
        exit 1
      end
      cluster_name_required(@node_args)
      @node_args.name = @pos_args[0]
      delete_node(@gflags, @node_args)

    when SubCommands::VolumeCreate
      if @pos_args.size < 2
        STDERR.puts "Volume name or bricks are not specified"
        exit 1
      end
      cluster_name_required(@volume_args)
      @volume_args.name = @pos_args[0]
      # Except first argument, all other arguments are Bricks
      @volume_args.bricks = @pos_args[1 .. -1]
      create_volume(@gflags, @volume_args)

    when SubCommands::VolumeList
      cluster_name_required(@volume_args)
      show_volumes(@gflags, @volume_args)

    when SubCommands::VolumeInfo
      cluster_name_required(@volume_args)
      volumes_info(@gflags, @volume_args)

    end
  end
end

commands = MoanaCommands.new
commands.parse
