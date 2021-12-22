require "uuid"

require "moana_types"
require "db"

module Datastore
  struct NodeView
    include DB::Serializable
    property id = "", name = "", endpoint = "", pool_id = "", pool_name = ""
  end

  def self.nodes_query
    "SELECT nodes.id AS id,
            nodes.name AS name,
            nodes.endpoint AS endpoint,
            pools.id AS pool_id,
            pools.name AS pool_name
     FROM nodes
     INNER JOIN pools ON nodes.pool_id = pools.id
    "
  end

  private def self.grouped_nodes(nodes)
    nodes.map do |row|
      node = MoanaTypes::Node.new
      node.id = row.id
      node.name = row.name
      node.endpoint = row.endpoint
      node.pool = MoanaTypes::Pool.new
      node.pool.id = row.pool_id
      node.pool.name = row.pool_name

      node
    end
  end

  def self.list_nodes(pool_name)
    grouped_nodes(connection.query_all(nodes_query, as: NodeView))
  end

  def self.get_nodes(pool_name, node_names)
    nodes = [] of MoanaTypes::Node
    node_names.map do |node_name|
      node = get_node(pool_name, node_name)
      nodes << node if node
    end

    nodes
  end

  def self.node_exists?(pool_name, node_name)
    query = "SELECT COUNT(nodes.id) FROM nodes INNER JOIN pools ON pools.id = nodes.pool_id WHERE pools.name = ? AND nodes.name = ?"
    connection.scalar(query, pool_name, node_name).as(Int64) > 0
  end

  def self.get_node(pool_name, node_name)
    nodes = grouped_nodes(
      connection.query_all(nodes_query + " WHERE pools.name = ? AND nodes.name = ?", pool_name, node_name, as: NodeView)
    )
    nodes.size > 0 ? nodes[0] : nil
  end

  def self.create_node(pool_id, node_id, node_name, endpoint, token)
    query = insert_query("nodes", %w[pool_id id name endpoint token])
    connection.exec(query, pool_id, node_id, node_name, endpoint, token)
  end
end
