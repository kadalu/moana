require "uuid"

require "moana_types"

module Datastore
  def self.node_dir(cluster_name, node_name)
    Path.new(@@rootdir, "clusters", cluster_name, "nodes", node_name)
  end

  def self.node_file(cluster_name, node_name)
    Path.new(node_dir(cluster_name, node_name), "info")
  end

  def self.save_node(cluster_name, node)
    Dir.mkdir_p(node_dir(cluster_name, node.name))
    File.write(node_file(cluster_name, node.name), node.to_json)

    node
  end

  def self.get_nodes(cluster_name, node_names)
    node_names.map do |node_name|
      # TODO: How to handle if node info not exists
      get_node(cluster_name, node_name).not_nil!
    end
  end

  def self.get_node(cluster_name, node_name)
    node_file_path = node_file(cluster_name, node_name)
    return nil unless File.exists?(node_file_path)

    MoanaTypes::Node.from_json(File.read(node_file_path).strip)
  end

  def self.create_node(cluster_name, node_id, node_name, endpoint, addresses, token)
    node = get_node(cluster_name, node_name)
    return node unless node.nil?

    node = MoanaTypes::Node.new
    node.id = node_id
    node.name = node_name
    node.addresses = addresses
    if addresses.size == 0
      node.addresses = [node_name]
    end
    node.endpoint = endpoint
    node.token = token
    save_node(cluster_name, node)
  end
end
