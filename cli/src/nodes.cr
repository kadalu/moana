require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

struct NodeJoinArgs < Args
  property hostname = "",
           endpoint = "",
           token = "ABCD"  # TODO: Replace this

  def pos_args(args : Array(String))
    if args.size != 1
      STDERR.puts "Node Endpoint not specified"
      exit 1
    end
    @endpoint = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      node = cluster.node_join(@endpoint, @token)
      save_and_get_clusters_list(gflags.moana_url)
      puts "Node joined successfully."
      puts "ID: #{node.id}"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end

end

struct NodeUpdateArgs < Args
  property hostname = "",
           new_hostname = "",
           endpoint = ""

  def handle(gflags : Gflags)
    cluster_id, node_id = cluster_and_node_id_from_name(@cluster_name, @hostname)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      cluster.node(node_id).update(@new_hostname, @endpoint)
      save_and_get_clusters_list(gflags.moana_url)
      puts "Node updated successfully"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end

end

struct NodeListArgs < Args
  property hostname = ""

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      nodes_data = cluster.nodes
      if nodes_data
        printf("%-36s  %-25s  %-s\n", "ID", "Name", "Endpoint")
      end
      nodes_data.each do |node|
        if @hostname == "" || node.id == @hostname || node.hostname == @hostname
          printf("%-36s  %-25s  %-s\n", node.id, node.hostname, node.endpoint)
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
      exit 1
    end
  end
end

struct NodeLeaveArgs < Args
  property hostname = ""

  def pos_args(args : Array(String))
    if args.size != 1
      STDERR.puts "Nodename is not specified"
      exit 1
    end
    @hostname = args[0]

    # Call parent pos_args to set cluster_name
    super
  end

  def handle(gflags : Gflags)
    cluster_id, node_id = cluster_and_node_id_from_name(@cluster_name, @hostname)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      cluster.node(node_id).delete
      save_and_get_clusters_list(gflags.moana_url)
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
        args = NodeListArgs.new
        parser.banner = "Usage: moana node list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-n NAME", "--node=NAME", "Node name") { |name| args.hostname = name }

        @args = args
      end

      parser.on("join", "Join to a Moana Cluster") do
        args = NodeJoinArgs.new
        parser.banner = "Usage: moana node join ENDPOINT [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-t TOKEN", "--token=TOKEN", "Token") { |token| args.token = token }

        @args = args
      end

      parser.on("leave", "Leave from a Moana Cluster") do
        args = NodeLeaveArgs.new
        parser.banner = "Usage: moana node leave NAME [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end

      parser.on("update", "Update Moana Node") do
        args = NodeUpdateArgs.new
        parser.banner = "Usage: moana node update [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-n NAME", "Node name") { |name| args.hostname = name }
        parser.on("--new-name NAME", "New Node name") { |newname| args.new_hostname = newname }
        parser.on("--endpoint NAME", "Node Endpoint") { |endpoint| args.endpoint = endpoint }

        @args = args
      end
    end
  end
end
