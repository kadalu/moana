-- +micrate Up
CREATE TABLE nodes (
  id UUID PRIMARY KEY,
  cluster_id UUID,
  hostname VARCHAR,
  endpoint VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX nodes_cluster_id_idx ON nodes (cluster_id);

-- +micrate Down
DROP TABLE IF EXISTS nodes;
