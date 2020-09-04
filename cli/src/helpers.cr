require "path"
require "file"
require "dir"
require "http/client"

class Node
  include JSON::Serializable

  property id, hostname, endpoint

  def initialize(@id = "", @hostname="", @endpoint="")
  end
end

class Cluster
  include JSON::Serializable

  property id, name, nodes

  def initialize(@id = "", @name = "", @nodes : Array(Node)? = [] of Node)
  end
end

class Task
  include JSON::Serializable

  property id

  def initialize(@id = "")
  end
end

class Brick
  include JSON::Serializable

  property node, path, device, port

  def initialize(@node = Node.new, @path = "", @device = "", @port = 0)
  end
end

class Volume
  include JSON::Serializable

  property id, name, type, state, brick_fs, bricks, xfs_opts, zfs_opts, ext4_opts, replica_count, disperse_count, start

  def initialize(@id = "", @name = "", @type = "", @state = "", @brick_fs = "dir", @bricks = [] of Brick, @xfs_opts = "", @zfs_opts = "", @ext4_opts = "", @replica_count = 1, @disperse_count = 1, @start = false)
  end
end

def cluster_id_from_name(name)
  filename = Path.home.join(".moana", "clusters.json")
  content = File.read(filename)
  cluster_data = Array(Cluster).from_json(content)
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
  cluster_data = Array(Cluster).from_json(content)
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
  cluster_data = Array(Cluster).from_json(content)
  cluster_data.each do |cluster|
    if cluster.id == cluster_id
      return cluster.nodes
    end
  end

  return nil
end

def save_and_get_clusters_list(base_url)
  filename = Path.home.join(".moana", "clusters.json")
  url = "#{base_url}/api/clusters"
  response = HTTP::Client.get url
  content = ""
  if response.status_code == 200
    content = response.body
    Dir.mkdir_p(Path[filename].parent)
    File.write(filename, content)
  end

  content
end
