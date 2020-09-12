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

  property node : Node, path : String, device : String, port : Int32
end

class Volume
  include JSON::Serializable

  property id : String,
           name : String,
           type : String,
           state : String,
           brick_fs : String?,
           bricks : Array(Brick),
           xfs_opts : String?,
           zfs_opts : String?,
           ext4_opts : String?,
           replica_count : Int32?,
           disperse_count : Int32?
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
