require "option_parser"

require "./clusters"

enum SubCommands
  Unknown
  ClusterCreate
  ClusterEdit
  ClusterList
  ClusterDelete
end

pos_args = [] of String

struct Gflags
  property moana_url

  def initialize(@moana_url : String)
  end
end

struct ClusterArgs
  property name, newname

  def initialize(@name : String = "", @newname : String = "")
  end
end

cluster_args = ClusterArgs.new
subcmd = SubCommands::Unknown

parser = OptionParser.new do |parser|
  parser.banner = "Usage: moana <subcommand> [arguments]"
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

    parser.on("edit", "Update Moana Cluster") do
      subcmd = SubCommands::ClusterEdit
      parser.banner = "Usage: moana cluster edit NEWNAME [arguments]"
      parser.on("-c NAME", "Cluster name") { |name| cluster_args.name = name }
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

case subcmd
when SubCommands::ClusterList
  show_clusters(gflags, cluster_args)
when SubCommands::ClusterCreate
  cluster_name_validate(pos_args)
  cluster_args.name = pos_args[0]
  create_cluster(gflags, cluster_args)
when SubCommands::ClusterEdit
  cluster_name_validate(pos_args)
  cluster_args.newname = pos_args[0]
  update_cluster(gflags, cluster_args)
when SubCommands::ClusterDelete
  cluster_name_validate(pos_args)
  cluster_args.name = pos_args[0]
  delete_cluster(gflags, cluster_args)
end
