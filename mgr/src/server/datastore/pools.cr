require "uuid"

require "db"
require "moana_types"

module Datastore
  struct PoolView
    include DB::Serializable

    property id = "", name = "", state = "", type = "", snapshot_plugin = "", size_bytes : Int64 = 0, inodes_count : Int64 = 0,
      distribute_group_index = 0, replica_count = 0, arbiter_count = 0, disperse_count = 0, redundancy_count = 0,
      replica_keyword = "", distribute_group_type = "", distribute_group_size_bytes : Int64 = 0,
      distribute_group_inodes_count : Int64 = 0, storage_unit_index = 0, node_id = "", node_name = "",
      node_endpoint = "", storage_unit_path = "", storage_unit_port = 0, storage_unit_fs = "",
      storage_unit_type = "", storage_unit_size_bytes : Int64 = 0, storage_unit_inodes_count : Int64 = 0,
      storage_unit_id = "", options = "{}"
  end

  def pools_exists?
    query = "SELECT COUNT(id) FROM pools"
    connection.scalar(query).as(Int64) > 0
  end

  private def group_pools(data)
    grouped_data = data.group_by do |rec|
      [rec.id]
    end

    grouped_data.map do |_, rows|
      pool = MoanaTypes::Pool.new
      pool.id = rows[0].id
      pool.name = rows[0].name
      pool.state = rows[0].state
      pool.options = Hash(String, String).from_json(rows[0].options)
      pool.metrics.size_bytes = rows[0].size_bytes
      pool.metrics.inodes_count = rows[0].inodes_count

      dist_grp_data = rows.group_by do |rec|
        [rec.distribute_group_index]
      end

      pool.distribute_groups = dist_grp_data.map do |_, rows2|
        dist_grp = MoanaTypes::DistributeGroup.new
        dist_grp.replica_count = rows2[0].replica_count
        dist_grp.arbiter_count = rows2[0].arbiter_count
        dist_grp.disperse_count = rows2[0].disperse_count
        dist_grp.redundancy_count = rows2[0].redundancy_count
        dist_grp.replica_keyword = rows2[0].replica_keyword
        dist_grp.metrics.size_bytes = rows2[0].distribute_group_size_bytes
        dist_grp.metrics.inodes_count = rows2[0].distribute_group_inodes_count

        units_data = rows2.group_by do |rec|
          [rec.storage_unit_index]
        end

        dist_grp.storage_units = units_data.map do |_, rows3|
          storage_unit = MoanaTypes::StorageUnit.new
          storage_unit.id = rows3[0].storage_unit_id
          storage_unit.path = rows3[0].storage_unit_path
          storage_unit.port = rows3[0].storage_unit_port
          storage_unit.metrics.size_bytes = rows3[0].storage_unit_size_bytes
          storage_unit.metrics.inodes_count = rows3[0].storage_unit_inodes_count

          storage_unit.node.id = rows3[0].node_id
          storage_unit.node.name = rows3[0].node_name
          storage_unit.node.endpoint = rows3[0].node_endpoint

          storage_unit
        end

        dist_grp
      end

      pool
    end
  end

  private def pools_query
    "SELECT pools.id AS id,
            pools.name AS name,
            pools.state AS state,
            pools.snapshot_plugin AS snapshot_plugin,
            pools.type AS type,
            pools.options AS options,
            pools.size_bytes AS size_bytes,
            pools.inodes_count AS inodes_count,
            distribute_groups.idx AS distribute_group_index,
            distribute_groups.replica_count AS replica_count,
            distribute_groups.arbiter_count AS arbiter_count,
            distribute_groups.disperse_count AS disperse_count,
            distribute_groups.redundancy_count AS redundancy_count,
            distribute_groups.replica_keyword AS replica_keyword,
            distribute_groups.type AS distribute_group_type,
            distribute_groups.size_bytes AS distribute_group_size_bytes,
            distribute_groups.inodes_count AS distribute_group_inodes_count,
            storage_units.idx AS storage_unit_index,
            nodes.id AS node_id,
            nodes.name AS node_name,
            nodes.endpoint AS node_endpoint,
            storage_units.id AS storage_unit_id,
            storage_units.path AS storage_unit_path,
            storage_units.port AS storage_unit_port,
            storage_units.fs AS storage_unit_fs,
            storage_units.type AS storage_unit_type,
            storage_units.size_bytes AS storage_unit_size_bytes,
            storage_units.inodes_count AS storage_unit_inodes_count
     FROM pools
     INNER JOIN distribute_groups ON pools.id = distribute_groups.pool_id
     INNER JOIN storage_units ON storage_units.pool_id = pools.id AND storage_units.distribute_group_id = distribute_groups.id
     INNER JOIN nodes ON nodes.id = storage_units.node_id
    "
  end

  private def pools_query_order_by
    " ORDER BY pools.created_on DESC, distribute_groups.idx ASC, storage_units.idx ASC "
  end

  def list_pools
    query = pools_query + pools_query_order_by
    group_pools(
      connection.query_all(query, as: PoolView)
    )
  end

  def list_pools_by_user(user_id)
    pool_ids = viewable_pool_ids(user_id)
    pools = list_pools

    # If user is having permission to view all Pools
    return pools if pool_ids.includes?("all")

    # Select the Pools only if user is having atleast view permission
    # to all Pools or the selected pools
    pools.select! do |pool|
      pool_ids.includes?(pool.id)
    end

    pools
  end

  def get_pool(pool_name)
    query = pools_query + " WHERE pools.name = ? " + pools_query_order_by
    pools = group_pools(
      connection.query_all(query, pool_name, as: PoolView)
    )

    pools.size > 0 ? pools[0] : nil
  end

  def create_pool(pool)
    pool_query = insert_query(
      "pools",
      %w[id name type state snapshot_plugin size_bytes inodes_count]
    )

    dist_grp_query = insert_query(
      "distribute_groups",
      %w[pool_id id idx replica_count arbiter_count disperse_count redundancy_count replica_keyword type size_bytes inodes_count]
    )
    storage_unit_query = insert_query(
      "storage_units",
      %w[id pool_id distribute_group_id idx node_id port path type fs size_bytes inodes_count]
    )
    connection.transaction do |tx|
      conn = tx.connection

      conn.exec(
        pool_query,
        pool.id,
        pool.name,
        pool.type,
        pool.state,
        pool.snapshot_plugin,
        pool.metrics.size_bytes,
        pool.metrics.inodes_count
      )

      pool.distribute_groups.each_with_index do |dist_grp, grp_idx|
        grp_id = UUID.random.to_s
        conn.exec(
          dist_grp_query,
          pool.id,
          grp_id,
          grp_idx,
          dist_grp.replica_count,
          dist_grp.arbiter_count,
          dist_grp.disperse_count,
          dist_grp.redundancy_count,
          dist_grp.replica_keyword,
          dist_grp.type,
          dist_grp.metrics.size_bytes,
          dist_grp.metrics.inodes_count
        )
        dist_grp.storage_units.each_with_index do |storage_unit, unit_idx|
          conn.exec(
            storage_unit_query,
            storage_unit.id,
            pool.id,
            grp_id,
            unit_idx,
            storage_unit.node.id,
            storage_unit.port,
            storage_unit.path,
            storage_unit.type,
            storage_unit.fs,
            storage_unit.metrics.size_bytes,
            storage_unit.metrics.inodes_count,
          )
        end
      end
    end
  end

  def update_pool_options(pool_id, options)
    query = update_query("pools", ["options"], where: " id = ?")
    connection.exec(query, options.to_json, pool_id)
  end

  # For expansion of pool
  def update_pool(pool, prev_grp_idx)
    pool_query = update_query(
      "pools",
      %w[id name type state snapshot_plugin size_bytes inodes_count],
      where: "id = ?"
    )

    dist_grp_query = insert_query(
      "distribute_groups",
      %w[pool_id id idx replica_count arbiter_count disperse_count redundancy_count replica_keyword type size_bytes inodes_count]
    )
    storage_unit_query = insert_query(
      "storage_units",
      %w[id pool_id distribute_group_id idx node_id port path type fs size_bytes inodes_count]
    )
    connection.transaction do |tx|
      conn = tx.connection

      conn.exec(
        pool_query,
        pool.id,
        pool.name,
        pool.type,
        pool.state,
        pool.snapshot_plugin,
        pool.metrics.size_bytes,
        pool.metrics.inodes_count,
        pool.id
      )

      pool.distribute_groups.each_with_index(prev_grp_idx) do |dist_grp, grp_idx|
        grp_id = UUID.random.to_s
        conn.exec(
          dist_grp_query,
          pool.id,
          grp_id,
          grp_idx,
          dist_grp.replica_count,
          dist_grp.arbiter_count,
          dist_grp.disperse_count,
          dist_grp.redundancy_count,
          dist_grp.replica_keyword,
          dist_grp.type,
          dist_grp.metrics.size_bytes,
          dist_grp.metrics.inodes_count
        )
        dist_grp.storage_units.each_with_index do |storage_unit, unit_idx|
          conn.exec(
            storage_unit_query,
            storage_unit.id,
            pool.id,
            grp_id,
            unit_idx,
            storage_unit.node.id,
            storage_unit.port,
            storage_unit.path,
            storage_unit.type,
            storage_unit.fs,
            storage_unit.metrics.size_bytes,
            storage_unit.metrics.inodes_count,
          )
        end
      end
    end
  end

  def update_pool_state(pool_id, state)
    query = update_query("pools", ["state"], where: " id = ?")
    connection.exec(query, state, pool_id)
  end

  def delete_pool(pool_id)
    connection.transaction do |tx|
      conn = tx.connection

      # TODO: Delete the Services

      query = "DELETE FROM storage_units WHERE pool_id = ?"
      conn.exec(query, pool_id)

      query = "DELETE FROM distribute_groups WHERE pool_id = ?"
      conn.exec(query, pool_id)

      query = "DELETE FROM pools WHERE id = ?"
      conn.exec(query, pool_id)
    end
  end

  def pool_exists_by_id?(pool_id)
    query = "SELECT COUNT(id) FROM pools WHERE id = ?"
    connection.scalar(query, pool_id).as(Int64) > 0
  end

  def rename_pool(pool_id, new_name)
    query = "UPDATE pools SET name = ? WHERE id = ?"
    connection.exec(query, new_name, pool_id)
  end

  def pool_name_exists_by_id?(name, pool_id)
    query = "SELECT COUNT(name) FROM pools WHERE name = ? and id = ?"
    connection.scalar(query, name, pool_id).as(Int64) > 0
  end
end
