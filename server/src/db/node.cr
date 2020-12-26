require "json"
require "uuid"

require "sqlite3"
require "moana_types"

NODE_SELECT_QUERY = <<-SQL
  SELECT id,
         hostname,
         endpoint,
         cluster_id
  FROM nodes
SQL

module MoanaDB
  def self.create_table_nodes(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS nodes (
       id UUID PRIMARY KEY,
       cluster_id UUID,
       hostname VARCHAR,
       endpoint VARCHAR,
       created_at TIMESTAMP,
       updated_at TIMESTAMP
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS nodes_cluster_id_idx ON nodes (cluster_id);"
  end

  def self.list_nodes(node_ids : Array(String), conn = @@conn)
    parts = [] of String
    params = [] of DB::Any
    node_ids.each do |node_id|
      parts <<  "?"
      params << node_id
    end
    query = "#{NODE_SELECT_QUERY} WHERE id IN (#{parts.join(",")})"

    conn.not_nil!.query_all(query, args: params, as: MoanaTypes::Node)
  end

  def self.list_nodes(conn = @@conn)
    conn.not_nil!.query_all(NODE_SELECT_QUERY, as: MoanaTypes::Node)
  end

  def self.list_nodes(cluster_id : String, conn = @@conn)
    conn.not_nil!.query_all("#{NODE_SELECT_QUERY} WHERE cluster_id = ?", cluster_id, as: MoanaTypes::Node)
  end

  def self.get_node(id : String, conn = @@conn)
    nodes = conn.not_nil!.query_all("#{NODE_SELECT_QUERY} WHERE id = ?", id, as: MoanaTypes::Node)

    return nil if nodes.size == 0
    nodes[0]
  end

  def self.create_node(cluster_id : String, hostname : String, endpoint : String, conn = @@conn)
    query = "INSERT INTO nodes(id, cluster_id, hostname, endpoint, created_at, updated_at)
             VALUES           (?,  ?,          ?,        ?,        datetime(), datetime());"

    node_id = UUID.random.to_s
    conn.not_nil!.exec(
      query,
      node_id,
      cluster_id,
      hostname,
      endpoint
    )

    MoanaTypes::Node.new(node_id, hostname, endpoint)
  end

  def self.update_node(id : String, hostname : String? = nil, endpoint : String? = nil, conn = @@conn)
    query = "UPDATE nodes SET "
    params = [] of DB::Any
    if !hostname.nil?
      query += "hostname = ?, "
      params << hostname
    end

    if !endpoint.nil?
      query += "endpoint = ?, "
      params << endpoint
    end

    params << id

    query += "updated_at = datetime() WHERE id = ?"

    conn.not_nil!.exec(query, args: params)

    get_node(id)
  end

  def self.delete_node(id : String, conn = @@conn)
    query = "DELETE FROM nodes WHERE id = ?"
    @@conn.not_nil!.exec(query, id)
  end
end
