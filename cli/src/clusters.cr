require "json"
require "path"
require "file"

require "./helpers"
require "moana_client"
require "moana_types"


struct ClusterCreateArgs < Args
  def pos_args(args : Array(String))
    @cluster_name = cluster_name_from_pos_args(args)
  end

  def handle(gflags : Gflags)
    client = MoanaClient::Client.new(gflags.moana_url)
    begin
      cluster = client.cluster_create(@cluster_name)
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
end

struct ClusterUpdateArgs < Args
  property cluster_newname = ""

  def pos_args(args : Array(String))
    @cluster_newname = cluster_name_from_pos_args(args)

    super
  end

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)

    begin
      cluster.update(@cluster_newname)
      save_and_get_clusters_list(gflags.moana_url)
      puts "Cluster updated successfully"
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts ex.status_code
    end
  end
end

struct ClusterListArgs < Args
  def handle(gflags : Gflags)
    cluster_data = save_and_get_clusters_list(gflags.moana_url)
    default_cluster_id = default_cluster()
    if cluster_data
      printf(" %-36s  %-s\n", "ID", "Name")
    end
    cluster_data.each do |cluster|
      if @cluster_name == "" || cluster.id == @cluster_name || cluster.name == @cluster_name
        pfx = " "
        pfx = "*" if cluster.id == default_cluster_id
        printf("%s%-36s  %-s\n", pfx, cluster.id, cluster.name)
      end
    end
  end
end

struct ClusterDeleteArgs < Args
  def pos_args(args : Array(String))
    @cluster_name = cluster_name_from_pos_args(args)
  end

  
  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
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
end

struct ClusterSetDefaultArgs < Args
  def pos_args(args : Array(String))
    @cluster_name = cluster_name_from_pos_args(args)
  end

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    save_default_cluster(cluster_id)
    puts "Default cluster set successfully.\n"
    puts "Note: The default cluster details is stored locally in this node"
  end

end

class MoanaCommands
  def cluster_commands(parser)
    parser.on("cluster", "Manage Moana Clusters") do
      parser.banner = "Usage: moana cluster <subcommand> [arguments]"
      parser.on("list", "List Moana Clusters") do
        args = ClusterListArgs.new
        parser.banner = "Usage: moana cluster list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        @args = args
      end

      parser.on("default", "Set default Cluster") do
        @args = ClusterSetDefaultArgs.new
        parser.banner = "Usage: moana cluster default NAME"
      end

      parser.on("create", "Create Moana Cluster") do
        @args = ClusterCreateArgs.new
        parser.banner = "Usage: moana cluster create NAME [arguments]"
      end

      parser.on("delete", "Delete Moana Cluster") do
        @args = ClusterDeleteArgs.new
        parser.banner = "Usage: moana cluster delete NAME [arguments]"
      end

      parser.on("update", "Update Moana Cluster") do
        args = ClusterUpdateArgs.new
        parser.banner = "Usage: moana cluster update NEWNAME [arguments]"
        parser.on("-c NAME", "Cluster name") { |name| args.cluster_name = name }

        @args = args
      end
    end
  end
end

def save_default_cluster(cluster_id)
  filename = Path.home.join(".moana", "default_cluster")
  File.write(filename, cluster_id)
end
