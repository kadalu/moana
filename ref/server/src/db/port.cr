require "json"
require "uuid"

require "sqlite3"

module MoanaDB
  def self.create_table_ports(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS ports (
       node_id    UUID,
       port       SMALLINT,
       created_at TIMESTAMP,
       updated_at TIMESTAMP,
       PRIMARY KEY (node_id, port)
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS ports_node_id_idx ON ports (node_id);"
  end

  def self.list_ports_by_node(node_id : String, conn = @@conn)
    query = "SELECT port FROM ports WHERE node_id = ?"
    conn.not_nil!.query_all(query, node_id, as: Int32)
  end

  def self.create_port(node_id : String, port : Int32, conn = @@conn)
    query = "INSERT INTO ports(node_id, port, created_at, updated_at)
             VALUES           (?,       ?,    datetime(), datetime())"

    conn.not_nil!.exec(
      query,
      node_id,
      port
    )

    port
  end

  def self.delete_expired_ports(node_id : String, conn = @@conn)
    query = "DELETE FROM ports WHERE node_id = ? AND updated_at < datetime('now', '-5 minutes')"
    @@conn.not_nil!.exec(query, node_id)
  end
end
