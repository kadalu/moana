require "json"
require "path"
require "file"

require "./helpers"
require "moana_client"
require "moana_types"

struct ClusterCreateCommand < Command
  def pos_args(args : Array(String))
    @args.cluster.name = cluster_name_from_pos_args(args)
  end

  def handle
    client = moana_client(@gflags.kadalu_mgmt_server)
    begin
      cluster = client.create_cluster(@args.cluster.name)
      save_and_get_clusters_list(@gflags.kadalu_mgmt_server)
      default_cluster_id = default_cluster()
      puts "Cluster created successfully."
      puts "ID: #{cluster.id}"
      if default_cluster_id == ""
        save_default_cluster(cluster.id)
        puts "\nSaved as default Cluster"
      end
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

struct ClusterUpdateCommand < Command
  def pos_args(args : Array(String))
    @args.cluster.newname = cluster_name_from_pos_args(args)

    super
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)

    begin
      cluster.update(@args.cluster.newname)
      save_and_get_clusters_list(@gflags.kadalu_mgmt_server)
      puts "Cluster updated successfully"
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
    end
  end
end

struct ClusterListCommand < Command
  # Override the default behaviour by defining empty function
  def pos_args(args : Array(String))
  end

  def handle
    cluster_data = save_and_get_clusters_list(@gflags.kadalu_mgmt_server)
    default_cluster_id = default_cluster()
    if cluster_data.size > 0
      printf(" %-36s  %-s\n", "ID", "Name")
    end
    cluster_data.each do |cluster|
      if @args.cluster.name == "" || cluster.id == @args.cluster.name || cluster.name == @args.cluster.name
        pfx = " "
        pfx = "*" if cluster.id == default_cluster_id
        printf("%s%-36s  %-s\n", pfx, cluster.id, cluster.name)
      end
    end
  end
end

struct ClusterDeleteCommand < Command
  def pos_args(args : Array(String))
    @args.cluster.name = cluster_name_from_pos_args(args)
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)

    begin
      cluster.delete
      default_cluster_id = default_cluster()
      save_and_get_clusters_list(@gflags.kadalu_mgmt_server)
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
      end

      handle_moana_client_exception(ex)
    end
  end
end

struct ClusterSetDefaultCommand < Command
  def pos_args(args : Array(String))
    @args.cluster.name = cluster_name_from_pos_args(args)
  end

  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    save_default_cluster(cluster_id)
    puts "Default cluster set successfully.\n"
    puts "Note: The default cluster details is stored locally in this node"
  end
end

class MoanaCommands
  def cluster_commands(parser)
    parser.on("cluster", "Manage #{PRODUCT} Clusters") do
      parser.banner = "Usage: #{COMMAND} cluster <subcommand> [arguments]"
      parser.on("list", "List Kadalu Storage Clusters") do
        @command_type = CommandType::ClusterList
        parser.banner = "Usage: #{COMMAND} cluster list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
      end

      parser.on("default", "Set default Cluster") do
        @command_type = CommandType::ClusterSetDefault
        parser.banner = "Usage: #{COMMAND} cluster default NAME"
      end

      parser.on("create", "Create #{PRODUCT} Cluster") do
        @command_type = CommandType::ClusterCreate
        parser.banner = "Usage: #{COMMAND} cluster create NAME [arguments]"
      end

      parser.on("delete", "Delete #{PRODUCT} Cluster") do
        @command_type = CommandType::ClusterDelete
        parser.banner = "Usage: #{COMMAND} cluster delete NAME [arguments]"
      end

      parser.on("update", "Update #{PRODUCT} Cluster") do
        @command_type = CommandType::ClusterUpdate
        parser.banner = "Usage: #{COMMAND} cluster update NEWNAME [arguments]"
        parser.on("-c NAME", "Cluster name") { |name| @args.cluster.name = name }
      end
    end
  end
end

def save_default_cluster(cluster_id)
  filename = Path.home.join(".kadalu", "default_cluster")
  File.write(filename, cluster_id)
end
