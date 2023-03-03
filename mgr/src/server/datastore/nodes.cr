require "uuid"

require "moana_types"
require "db"

module Datastore
  struct NodeView
    include DB::Serializable
    property id = "", name = "", endpoint = ""
  end

  private def nodes_query
    "SELECT nodes.id AS id,
            nodes.name AS name,
            nodes.endpoint AS endpoint
     FROM nodes
    "
  end

  private def nodes_query_order_by
    " ORDER BY nodes.created_on DESC "
  end

  def list_nodes
    connection.query_all(nodes_query + nodes_query_order_by, as: MoanaTypes::Node)
  end

  # def list_nodes_by_user(user_id)
  #   pool_ids = viewable_pool_ids(user_id)
  #   return list_nodes if pool_ids.includes?("all")

  #   query = nodes_query + " WHERE pools.id IN (#{(pool_ids.map { |_| "?" }).join(",")}) " + nodes_query_order_by
  #   connection.query_all(query, args: pool_ids, as: MoanaTypes::Node)
  # end

  def get_nodes(node_names)
    nodes = [] of MoanaTypes::Node
    node_names.map do |node_name|
      node = get_node(node_name)
      nodes << node if node
    end

    nodes
  end

  def node_exists?(node_name)
    query = "SELECT COUNT(nodes.id) FROM nodes WHERE nodes.name = ?"
    connection.scalar(query, node_name).as(Int64) > 0
  end

  def get_node(node_name)
    nodes = connection.query_all(nodes_query + " WHERE nodes.name = ?", node_name, as: MoanaTypes::Node)
    nodes.size > 0 ? nodes[0] : nil
  end

  def create_node(node_id, node_name, endpoint, token, mgr_token)
    mgr_token_hash = hash_sha256(mgr_token)
    query = insert_query("nodes", %w[id name endpoint token mgr_token_hash])
    connection.exec(query, node_id, node_name, endpoint, token, mgr_token_hash)
  end

  def storage_units_from_node?(node_id)
    query = "SELECT COUNT(1) FROM storage_units WHERE node_id = ?"
    connection.scalar(query, node_id).as(Int64) > 0
  end

  def delete_node(node_id)
    query = "DELETE FROM nodes WHERE id = ?"
    connection.exec(query, node_id)
  end

  def node_tokens(nodes : Array(MoanaTypes::Node))
    node_ids = [] of String
    nodes.each do |node|
      node_ids << node.id unless node.id == ""
    end

    in_node_ids = (node_ids.map { |_| "?" }).join(",")
    query = "SELECT id, token FROM nodes WHERE id IN (#{in_node_ids})"
    tokens = connection.query_all(query, args: node_ids, as: {String, String})
    tokens_hash = Hash(String, String).new
    tokens.each do |token|
      tokens_hash[token[0]] = token[1]
    end

    nodes.map do |node|
      if tokens_hash[node.id]?
        node.token = tokens_hash[node.id]
      end

      node
    end
  end
end
