require "http/client"
require "json"
require "path"
require "file"

require "./helpers"

def show_nodes(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    nodes_data = cluster.nodes
    if nodes_data
      printf("%-36s  %-25s  %-s\n", "ID", "Name", "Endpoint")
    end
    nodes_data.each do |node|
      if args.name == "" || node.id == args.name || node.hostname == args.name
        printf("%-36s  %-25s  %-s\n", node.id, node.hostname, node.endpoint)
      end
    end
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end

def create_node(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    node = cluster.node_create(args.endpoint, args.token)
    save_and_get_clusters_list(gflags.moana_url)
    puts "Node joined successfully."
    puts "ID: #{node.id}"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
  end
end

def update_node(gflags, args)
  cluster_id, node_id = cluster_and_node_id_from_name(args.cluster_name, args.name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    cluster.node(node_id).update(args.newname, args.endpoint)
    save_and_get_clusters_list(gflags.moana_url)
    puts "Node updated successfully"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
  end
end

def delete_node(gflags, args)
  cluster_id, node_id = cluster_and_node_id_from_name(args.cluster_name, args.name)
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
