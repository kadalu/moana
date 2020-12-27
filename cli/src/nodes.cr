require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

struct NodeJoinCommand < Command
  property hostname = "",
           endpoint = "",
           token = "ABCD"  # TODO: Replace this

  def pos_args(args : Array(String))
    if args.size != 1
      STDERR.puts "Node Endpoint not specified"
      exit 1
    end
    @args.node.endpoint = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = MoanaClient::Client.new(@gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      node = cluster.node_join(@args.node.endpoint, @args.node.token)
      save_and_get_clusters_list(@gflags.moana_url)
      puts "Node joined successfully."
      puts "ID: #{node.id}"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts "#{ex.message}(Code: #{ex.status_code})"
    end
  end
end

struct NodeUpdateCommand < Command
  property hostname = "",
           new_hostname = "",
           endpoint = ""

  def handle
    cluster_id, node_id = cluster_and_node_id_from_name(@args.cluster.name, @args.node.hostname)
    client = MoanaClient::Client.new(@gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      cluster.node(node_id).update(@args.node.new_hostname, @args.node.endpoint)
      save_and_get_clusters_list(@gflags.moana_url)
      puts "Node updated successfully"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end

end

struct NodeListCommand < Command
  property hostname = ""

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = MoanaClient::Client.new(@gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      nodes_data = cluster.nodes
      if nodes_data
        printf("%-36s  %-25s  %-s\n", "ID", "Name", "Endpoint")
      end
      nodes_data.each do |node|
        if @args.node.hostname == "" || node.id == @args.node.hostname || node.hostname == @args.node.hostname
          printf("%-36s  %-25s  %-s\n", node.id, node.hostname, node.endpoint)
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
      exit 1
    end
  end
end

struct NodeLeaveCommand < Command
  property hostname = ""

  def pos_args(args : Array(String))
    if args.size != 1
      STDERR.puts "Nodename is not specified"
      exit 1
    end
    @args.node.hostname = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle
    cluster_id, node_id = cluster_and_node_id_from_name(@args.cluster.name, @args.node.hostname)
    client = MoanaClient::Client.new(@gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      cluster.node(node_id).delete
      save_and_get_clusters_list(@gflags.moana_url)
      puts "Node removed from the Cluster"
    rescue ex : MoanaClient::MoanaClientException
      if ex.status_code == 404
        STDERR.puts "Invalid Cluster/Node name"
        exit
      else
        STDERR.puts ex.status_code
      end
    end
  end
end

class MoanaCommands
  def node_commands(parser)
    parser.on("node", "Manage Moana Nodes") do
      parser.banner = "Usage: moana node <subcommand> [arguments]"
      parser.on("list", "List Moana Nodes") do
        @command_type = CommandType::NodeList
        parser.banner = "Usage: moana node list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
          @args.cluster.name = name
        end
        parser.on("-n NAME", "--node=NAME", "Node name") do |name|
          @args.node.hostname = name
        end
      end

      parser.on("join", "Join to a Moana Cluster") do
        @command_type = CommandType::NodeJoin
        parser.banner = "Usage: moana node join ENDPOINT [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
          @args.cluster.name = name
        end
        parser.on("-t TOKEN", "--token=TOKEN", "Token") do |token|
          @args.node.token = token
        end
      end

      parser.on("leave", "Leave from a Moana Cluster") do
        @command_type = CommandType::NodeLeave
        parser.banner = "Usage: moana node leave NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
          @args.cluster.name = name
        end
      end

      parser.on("update", "Update Moana Node") do
        @command_type = CommandType::NodeUpdate
        parser.banner = "Usage: moana node update [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("-n NAME", "Node name") { |name| @args.node.hostname = name }
        parser.on("--new-name NAME", "New Node name") { |newname| @args.node.new_hostname = newname }
        parser.on("--endpoint NAME", "Node Endpoint") { |endpoint| @args.node.endpoint = endpoint }
      end
    end
  end
end
