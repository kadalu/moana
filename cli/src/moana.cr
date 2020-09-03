require "option_parser"

require "./clusters"
require "./nodes"

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
end

pos_args = [] of String

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

cluster_args = ClusterArgs.new
node_args = NodeArgs.new
subcmd = SubCommands::Unknown

parser = OptionParser.new do |parser|
  parser.banner = "Usage: moana <subcommand> [arguments]"

  # Cluster Sub commands
  parser.on("cluster", "Manage Moana Clusters") do
    parser.banner = "Usage: moana cluster <subcommand> [arguments]"
    parser.on("list", "List Moana Clusters") do
      subcmd = SubCommands::ClusterList
      parser.banner = "Usage: moana cluster list [arguments]"
      parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| cluster_args.name = name }
    end

    parser.on("create", "Create Moana Cluster") do
      subcmd = SubCommands::ClusterCreate
      parser.banner = "Usage: moana cluster create NAME [arguments]"
    end

    parser.on("delete", "Delete Moana Cluster") do
      subcmd = SubCommands::ClusterDelete
      parser.banner = "Usage: moana cluster delete NAME [arguments]"
    end

    parser.on("update", "Update Moana Cluster") do
      subcmd = SubCommands::ClusterUpdate
      parser.banner = "Usage: moana cluster update NEWNAME [arguments]"
      parser.on("-c NAME", "Cluster name") { |name| cluster_args.name = name }
    end

  end

  # Node Sub commands
  parser.on("node", "Manage Moana Nodes") do
    parser.banner = "Usage: moana node <subcommand> [arguments]"
    parser.on("list", "List Moana Nodes") do
      subcmd = SubCommands::NodeList
      parser.banner = "Usage: moana node list [arguments]"
      parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| node_args.cluster_name = name }
      parser.on("-n NAME", "--node=NAME", "Node name") { |name| node_args.name = name }
    end

    parser.on("join", "Join to a Moana Cluster") do
      subcmd = SubCommands::NodeJoin
      parser.banner = "Usage: moana node join NAME ENDPOINT [arguments]"
      parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| node_args.cluster_name = name }
    end

    parser.on("leave", "Leave from a Moana Cluster") do
      subcmd = SubCommands::NodeLeave
      parser.banner = "Usage: moana node leave NAME [arguments]"
      parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| node_args.cluster_name = name }
    end

    parser.on("update", "Update Moana Node") do
      subcmd = SubCommands::NodeUpdate
      parser.banner = "Usage: moana node update [arguments]"
      parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| node_args.cluster_name = name }
      parser.on("-n NAME", "Node name") { |name| node_args.name = name }
      parser.on("--new-name NAME", "New Node name") { |newname| node_args.newname = newname }
      parser.on("--endpoint NAME", "Node Endpoint") { |endpoint| node_args.endpoint = endpoint }
    end

  end

  #parser.on("-v", "--verbose", "Enabled servose output") { verbose = true }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.unknown_args do |args|
    pos_args = args
  end

  parser.invalid_option do |flag|
    STDERR.puts "Invalid Option: #{flag}"
    exit 1
  end

  parser.missing_option do |flag|
    STDERR.puts "Missing Option: #{flag}"
    exit 1
  end
end

parser.parse

gflags = Gflags.new ENV.fetch("MOANA_URL", "")
if gflags.moana_url == ""
  STDERR.puts "MOANA_URL environment variable is not set"
  exit 1
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

# Route each sub commands
case subcmd
when SubCommands::ClusterList
  show_clusters(gflags, cluster_args)

when SubCommands::ClusterCreate
  cluster_name_validate(pos_args)
  cluster_args.name = pos_args[0]
  create_cluster(gflags, cluster_args)

when SubCommands::ClusterUpdate
  cluster_name_validate(pos_args)
  cluster_args.newname = pos_args[0]
  update_cluster(gflags, cluster_args)

when SubCommands::ClusterDelete
  cluster_name_validate(pos_args)
  cluster_args.name = pos_args[0]
  delete_cluster(gflags, cluster_args)

when SubCommands::NodeList
  cluster_name_required(node_args)
  show_nodes(gflags, node_args)

when SubCommands::NodeJoin
  if pos_args.size != 2
    STDERR.puts "Nodename and Endpoint not specified"
    exit 1
  end
  cluster_name_required(node_args)
  node_args.name = pos_args[0]
  node_args.endpoint = pos_args[1]
  create_node(gflags, node_args)

when SubCommands::NodeUpdate
  cluster_name_required(node_args)
  update_node(gflags, node_args)

when SubCommands::NodeLeave
  if pos_args.size != 1
    STDERR.puts "Nodename is not specified"
    exit 1
  end
  cluster_name_required(node_args)
  node_args.name = pos_args[0]
  delete_node(gflags, node_args)
end
