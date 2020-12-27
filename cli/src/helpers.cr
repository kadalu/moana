require "json"
require "path"
require "file"
require "dir"
require "http/client"

require "moana_types"

enum CommandType
  Unknown
  ClusterCreate
  ClusterList
  ClusterUpdate
  ClusterSetDefault
  ClusterDelete

  NodeJoin
  NodeUpdate
  NodeLeave
  NodeList

  VolumeCreate
  VolumeStart
  VolumeStop
  VolumeSet
  VolumeReset
  VolumeDelete
  VolumeInfo
  VolumeList

  TaskList
end

struct Gflags
  property moana_url = ""

  def initialize
  end

  def initialize(@moana_url : String)
  end
end

struct ClusterArgs
  property name = "",
           newname = ""
end

struct NodeArgs
  property hostname = "",
           new_hostname = "",
           endpoint = "",
           token = ""
end

struct VolumeArgs
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
end

struct TaskArgs
  property id : String = ""
end

struct Args
  property cluster = ClusterArgs.new,
           node = NodeArgs.new,
           volume = VolumeArgs.new,
           task = TaskArgs.new
  
end

abstract struct Command
  property args = Args.new,
           gflags = Gflags.new

  abstract def handle

  def set_args(@gflags : Gflags, @args : Args, pargs : Array(String))
      pos_args(pargs)
  end

  def cluster_name_from_pos_args(args)
    if args.size != 1
      STDERR.puts "Cluster name is not specified"
      exit 1
    end

    args[0]
  end

  def pos_args(args : Array(String))
    return if @args.cluster.name != ""

    cluster = default_cluster()
    if cluster == ""
      STDERR.puts "Cluster name or ID not specified."
      STDERR.puts "Use `moana cluster default <name>` to set default Cluster."
      exit 1
    end

    @args.cluster.name = cluster
  end
end

struct UnknownCommand < Command
  def handle
    STDERR.puts "No command specified"
    exit 1
  end
end

def cluster_id_from_name(name)
  filename = Path.home.join(".moana", "clusters.json")
  content = File.read(filename)
  cluster_data = Array(MoanaTypes::Cluster).from_json(content)
  cluster_data.each do |cluster|
    if cluster.name == name || cluster.id == name
      return cluster.id
    end
  end

  return ""
end

def cluster_and_node_id_from_name(cluster_name, name)
  filename = Path.home.join(".moana", "clusters.json")
  content = File.read(filename)
  cluster_data = Array(MoanaTypes::Cluster).from_json(content)
  cluster_data.each do |cluster|
    if cluster.name == cluster_name || cluster.id == cluster_name
      if nodes = cluster.nodes
        nodes.each do |node|
          if node.hostname == name || node.id == name
            return [cluster.id, node.id]
          end
        end
      end
    end
  end

  return ["", ""]
end

def nodes_by_cluster_id(cluster_id)
  filename = Path.home.join(".moana", "clusters.json")
  content = File.read(filename)
  cluster_data = Array(MoanaTypes::Cluster).from_json(content)
  cluster_data.each do |cluster|
    if cluster.id == cluster_id
      return cluster.nodes
    end
  end

  return nil
end

def save_and_get_clusters_list(base_url)
  filename = Path.home.join(".moana", "clusters.json")
  client = MoanaClient::Client.new(base_url)

  begin
    clusters = client.clusters
    Dir.mkdir_p(Path[filename].parent)
    File.write(filename, clusters.to_json)

    clusters
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts "[#{ex.status_code}] #{ex.message}"
    exit
  end
end

def default_cluster
  filename = Path.home.join(".moana", "default_cluster")
  if File.exists?(filename)
    File.read(filename)
  else
    ""
  end
end

def prepare_bricks_list(cluster_id, data, brick_fs)
  if nodes = nodes_by_cluster_id(cluster_id)
    nodedata = {} of String => String
    nodes.each do |node|
      nodedata[node.hostname] = node.id
    end

    bricks = [] of MoanaTypes::BrickRequest
    data.each do |item|
      node_hostname, brick_path = item.split(":")
      node_id = nodedata.fetch(node_hostname, nil)
      if node_id.nil?
        STDERR.puts "Invalid node #{node_hostname}"
        exit 1
      end
      brick = MoanaTypes::BrickRequest.new
      brick.node_id = node_id

      if brick_fs == "dir"
        brick.path = brick_path
      else
        brick.device = brick_path
      end
      bricks << brick
    end

    bricks
  else
    STDERR.puts "Invalid Cluster ID or name"
    exit 1
  end

end

def volume_id_from_name(client, cluster_id, name)
  begin
    # TODO: Optimize this by calling search API
    # Now this is getting all volumes and searching
    volumes = client.cluster(cluster_id).volumes
    volumes.each do |volume|
      if volume.name == name || volume.id == name
        return volume.id
      end
    end

    STDERR.puts "Invalid Volume name"
    exit 1
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts "Failed to get Volume ID from the name(HTTP Error: #{ex.status_code})"
    exit 1
  end
end

def start_stop_volume(gflags, cluster_name, name, action)
  cluster_id = cluster_id_from_name(cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)

  begin
    volume_id = volume_id_from_name(client, cluster_id, name)
    volume = client.cluster(cluster_id).volume(volume_id)
    task = if action == "start"
             volume.start
           else
             volume.stop
           end
    puts "Volume #{action} request sent successfully."
    puts "Task ID: #{task.id}"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end
