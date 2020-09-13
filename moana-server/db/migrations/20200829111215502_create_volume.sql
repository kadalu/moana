-- +micrate Up
CREATE TABLE volumes (
  id UUID PRIMARY KEY,
  cluster_id UUID,
  name VARCHAR,
  state VARCHAR,
  type VARCHAR,
  replica_count INTEGER,
  disperse_count INTEGER,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX volumes_cluster_id_idx ON volumes (cluster_id);

-- +micrate Down
DROP TABLE IF EXISTS volumes;
