require "uuid"

require "moana_types"
require "db"

module Datastore
  struct NodeView
    include DB::Serializable
    property id = "", name = "", endpoint = "", pool_id = "", pool_name = ""
  end

  private def nodes_query
    "SELECT nodes.id AS id,
            nodes.name AS name,
            nodes.endpoint AS endpoint,
            pools.id AS pool_id,
            pools.name AS pool_name
     FROM nodes
     INNER JOIN pools ON nodes.pool_id = pools.id
    "
  end

  private def nodes_query_order_by
    " ORDER BY pools.created_on DESC, nodes.created_on DESC "
  end

  private def grouped_nodes(nodes)
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

  def list_nodes
    grouped_nodes(connection.query_all(nodes_query + nodes_query_order_by, as: NodeView))
  end

  def list_nodes_by_user(user_id)
    pool_ids = viewable_pool_ids(user_id)
    return list_nodes if pool_ids.includes?("all")

    query = nodes_query + " WHERE pools.id IN (#{(pool_ids.map { |_| "?" }).join(",")}) " + nodes_query_order_by
    grouped_nodes(connection.query_all(query, args: pool_ids, as: NodeView))
  end

  def list_nodes(pool_name)
    grouped_nodes(connection.query_all(nodes_query + " WHERE pools.name = ?" + nodes_query_order_by, pool_name, as: NodeView))
  end

  def get_nodes(pool_name, node_names)
    nodes = [] of MoanaTypes::Node
    node_names.map do |node_name|
      node = get_node(pool_name, node_name)
      nodes << node if node
    end

    nodes
  end

  def node_exists?(pool_name, node_name)
    query = "SELECT COUNT(nodes.id) FROM nodes INNER JOIN pools ON pools.id = nodes.pool_id WHERE pools.name = ? AND nodes.name = ?"
    connection.scalar(query, pool_name, node_name).as(Int64) > 0
  end

  def get_node(pool_name, node_name)
    nodes = grouped_nodes(
      connection.query_all(nodes_query + " WHERE pools.name = ? AND nodes.name = ?", pool_name, node_name, as: NodeView)
    )
    nodes.size > 0 ? nodes[0] : nil
  end

  def create_node(pool_id, node_id, node_name, endpoint, token)
    query = insert_query("nodes", %w[pool_id id name endpoint token])
    connection.exec(query, pool_id, node_id, node_name, endpoint, token)
  end
end
