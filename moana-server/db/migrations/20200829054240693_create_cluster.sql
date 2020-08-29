-- +micrate Up
CREATE TABLE clusters (
  id UUID PRIMARY KEY,
  name VARCHAR,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);


-- +micrate Down
DROP TABLE IF EXISTS clusters;
