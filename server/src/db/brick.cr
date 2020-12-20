require "json"
require "uuid"

require "sqlite3"


module MoanaDB
  def self.create_table_bricks(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS bricks (
       id         UUID PRIMARY KEY,
       cluster_id UUID,
       volume_id  UUID,
       order      INTEGER,
       node_id    UUID,
       path       VARCHAR,
       device     VARCHAR,
       port       INTEGER,
       state      VARCHAR,
       created_at TIMESTAMP,
       updated_at TIMESTAMP
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_cluster_id_idx ON bricks (cluster_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_node_id_idx ON bricks (node_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS bricks_volume_id_idx ON bricks (volume_id);"
  end
end
