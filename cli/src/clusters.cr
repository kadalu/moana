require "json"
require "path"
require "file"

require "./helpers"
require "moana_client"
require "moana_types"

include MoanaTypes

def show_clusters(gflags, args)
  cluster_data = save_and_get_clusters_list(gflags.moana_url)
  default_cluster_id = default_cluster()
  if cluster_data
    printf(" %-36s  %-s\n", "ID", "Name")
  end
  cluster_data.each do |cluster|
    if args.name == "" || cluster.id == args.name || cluster.name == args.name
      pfx = " "
      pfx = "*" if cluster.id == default_cluster_id
      printf("%s%-36s  %-s\n", pfx, cluster.id, cluster.name)
    end
  end
end

def save_default_cluster(cluster_id)
  filename = Path.home.join(".moana", "default_cluster")
  File.write(filename, cluster_id)
end

def set_default_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  save_default_cluster(cluster_id)
  puts "Default cluster set successfully.\n"
  puts "Note: The default cluster details is stored locally in this node"
end

def create_cluster(gflags, args)
  client = MoanaClient::Client.new(gflags.moana_url)
  begin
    cluster = client.cluster_create(args.name)
    save_and_get_clusters_list(gflags.moana_url)
    default_cluster_id = default_cluster()
    puts "Cluster created successfully."
    puts "ID: #{cluster.id}"
    if default_cluster_id == ""
      save_default_cluster(cluster.id)
      puts "\nSaved as default Cluster"
    end
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
  end
end

def update_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)

  begin
    cluster.update(args.newname)
    save_and_get_clusters_list(gflags.moana_url)
    puts "Cluster updated successfully"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
  end
end

def delete_cluster(gflags, args)
  cluster_id = cluster_id_from_name(args.name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)

  begin
    cluster.delete
    default_cluster_id = default_cluster()
    save_and_get_clusters_list(gflags.moana_url)
    # If the Cluster deleted is the default Cluster then
    # reset default cluster.
    if default_cluster_id == cluster_id
      save_default_cluster("")
    end
    puts "Cluster deleted successfully"
  rescue ex : MoanaClient::MoanaClientException
    if ex.status_code == 404
      STDERR.puts "Invalid Cluster name"
      exit
    else
      STDERR.puts ex.status_code
      exit
    end
  end
end
