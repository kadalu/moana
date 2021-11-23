require "json"
require "uuid"

require "sqlite3"

BRICK_SELECT_QUERY = <<-SQL
  SELECT id,
         path,
         port,
         device,
         state,
         type
  FROM bricks
SQL

module MoanaDB
  struct BrickView
    include DB::Serializable

    property id = "",
      path = "",
      port : Int32 = 0,
      device = "",
      state = "",
      type = ""
  end

  def self.create_table_bricks(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS bricks (
       id         UUID PRIMARY KEY,
       cluster_id UUID NOT NULL,
       volume_id  UUID NOT NULL,
       type       VARCHAR NOT NULL,
       idx        INTEGER NOT NULL,
       node_id    UUID NOT NULL,
       path       VARCHAR NOT NULL,
       device     VARCHAR NOT NULL DEFAULT '-',
       port       SMALLINT NOT NULL DEFAULT -1,
       state      VARCHAR NOT NULL DEFAULT '-',
       created_at TIMESTAMP,
       updated_at TIMESTAMP
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_cluster_id_idx ON bricks (cluster_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_node_id_idx ON bricks (node_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_volume_id_idx ON bricks (volume_id);"
  end

  def self.list_bricks_by_node(node_id : String, conn = @@conn)
    bricks = conn.not_nil!.query_all("#{BRICK_SELECT_QUERY} WHERE node_id = ?", node_id, as: BrickView)

    bricks.map do |brick|
      brk = MoanaTypes::Brick.new
      brk.id = brick.id
      brk.path = brick.path
      brk.port = brick.port
      brk.device = brick.device
      brk.state = brick.state
      brk.type = brick.type

      brk
    end
  end

  def self.list_brick_ports_by_node(node_id : String, conn = @@conn)
    query = "SELECT port FROM bricks WHERE node_id = ?"
    conn.not_nil!.query_all(query, node_id, as: Int32)
  end
end
