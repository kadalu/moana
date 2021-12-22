# Add Schemas here. If a change is required for
# a schema then add a new entry to modify the Schema
# if Backward compatibility is required to the
# previous version. Else Update the existing schema.
SCHEMAS = [
  "CREATE TABLE IF NOT EXISTS users (
       id            UUID PRIMARY KEY,
       username      VARCHAR UNIQUE,
       name          VARCHAR,
       password_hash VARCHAR,
       created_on    TIMESTAMP,
       updated_on    TIMESTAMP
   )",
  "CREATE TABLE IF NOT EXISTS pools (
       id          UUID PRIMARY KEY,
       name        VARCHAR UNIQUE,
       created_on  TIMESTAMP,
       updated_on  TIMESTAMP
   )",
  "CREATE TABLE IF NOT EXISTS roles (
       user_id     UUID,
       pool_id     UUID,
       volume_id   UUID,
       name        VARCHAR,
       created_on  TIMESTAMP,
       updated_on  TIMESTAMP,
       UNIQUE (user_id, pool_id, volume_id, name)
   )",
  "CREATE TABLE IF NOT EXISTS api_keys (
       user_id    UUID,
       name       VARCHAR,
       token      VARCHAR,
       token_hash VARCHAR,
       created_on TIMESTAMP,
       updated_on TIMESTAMP,
       UNIQUE (user_id, name)
   )",
  "CREATE TABLE IF NOT EXISTS nodes (
       id               UUID PRIMARY KEY,
       pool_id          UUID,
       name             VARCHAR,
       endpoint         VARCHAR UNIQUE,
       token            VARCHAR,
       mgmt_address     VARCHAR,
       volume_address   VARCHAR,
       heal_address     VARCHAR,
       internal_address VARCHAR,
       created_on       TIMESTAMP,
       updated_on       TIMESTAMP,
       UNIQUE (pool_id, name)
   )",
  "CREATE TABLE IF NOT EXISTS volumes (
       id                  UUID PRIMARY KEY,
       pool_id             UUID,
       name                VARCHAR,
       type                VARCHAR,
       state               VARCHAR,
       snapshot_plugin     VARCHAR,
       distribute_count    SMALLINT,
       storage_units_count SMALLINT,
       size_bytes          INTEGER,
       inodes_count        INTEGER,
       created_on          TIMESTAMP,
       updated_on          TIMESTAMP,
       UNIQUE (pool_id, name)
   )",
  "CREATE TABLE IF NOT EXISTS distribute_groups (
       id                  UUID PRIMARY KEY,
       pool_id             UUID,
       volume_id           UUID,
       idx                 SMALLINT,
       type                VARCHAR,
       replica_count       SMALLINT,
       arbiter_count       SMALLINT,
       disperse_count      SMALLINT,
       redundancy_count    SMALLINT,
       replica_keyword     VARCHAR,
       storage_units_count SMALLINT,
       size_bytes          INTEGER,
       inodes_count        INTEGER,
       created_on          TIMESTAMP,
       updated_on          TIMESTAMP,
       UNIQUE (pool_id, volume_id, idx)
   )",
  "CREATE TABLE IF NOT EXISTS storage_units (
       id                  UUID PRIMARY KEY,
       pool_id             UUID,
       volume_id           UUID,
       distribute_group_id UUID,
       idx                 SMALLINT,
       node_id             UUID,
       path                VARCHAR,
       port                SMALLINT,
       type                VARCHAR,
       fs                  VARCHAR,
       size_bytes          INTEGER,
       inodes_count        INTEGER,
       created_on          TIMESTAMP,
       updated_on          TIMESTAMP,
       UNIQUE (pool_id, node_id, path)
   )",
  "CREATE TABLE IF NOT EXISTS ports (
       pool_id    UUID,
       node_id    UUID,
       port       SMALLINT,
       created_on TIMESTAMP,
       updated_on TIMESTAMP,
       UNIQUE (pool_id, node_id, port)
    );",
]
