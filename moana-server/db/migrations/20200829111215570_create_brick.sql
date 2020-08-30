-- +micrate Up
CREATE TABLE bricks (
  id UUID PRIMARY KEY,
  cluster_id UUID,
  volume_id UUID,
  node_id UUID,
  path VARCHAR,
  device VARCHAR,
  port INT,
  state VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX bricks_cluster_id_idx ON bricks (cluster_id);
CREATE INDEX bricks_node_id_idx ON bricks (node_id);
CREATE INDEX bricks_volume_id_idx ON bricks (volume_id);

-- +micrate Down
DROP TABLE IF EXISTS bricks;
