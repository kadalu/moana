-- +micrate Up
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  cluster_id UUID,
  node_id UUID,
  data VARCHAR,
  state VARCHAR,
  type VARCHAR,
  response VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX tasks_cluster_id_idx ON tasks (cluster_id);
CREATE INDEX tasks_node_id_idx ON tasks (node_id);

-- +micrate Down
DROP TABLE IF EXISTS tasks;
