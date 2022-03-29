require "uuid"

require "db"
require "moana_types"

module Datastore
  struct VolumeView
    include DB::Serializable

    property id = "", name = "", state = "", type = "", snapshot_plugin = "", size_bytes : Int64 = 0, inodes_count : Int64 = 0,
      distribute_group_index = 0, replica_count = 0, arbiter_count = 0, disperse_count = 0, redundancy_count = 0,
      replica_keyword = "", distribute_group_type = "", distribute_group_size_bytes : Int64 = 0,
      distribute_group_inodes_count : Int64 = 0, storage_unit_index = 0, node_id = "", node_name = "",
      node_endpoint = "", storage_unit_path = "", storage_unit_port = 0, storage_unit_fs = "",
      storage_unit_type = "", storage_unit_size_bytes : Int64 = 0, storage_unit_inodes_count : Int64 = 0,
      pool_name = "", pool_id = "",
      storage_unit_id = "", options = "{}"
  end

  private def group_volumes(data)
    grouped_data = data.group_by do |rec|
      [rec.id]
    end

    grouped_data.map do |_, rows|
      volume = MoanaTypes::Volume.new
      volume.id = rows[0].id
      volume.name = rows[0].name
      volume.state = rows[0].state
      volume.options = Hash(String, String).from_json(rows[0].options)
      volume.metrics.size_bytes = rows[0].size_bytes
      volume.metrics.inodes_count = rows[0].inodes_count
      volume.pool.id = rows[0].pool_id
      volume.pool.name = rows[0].pool_name

      dist_grp_data = rows.group_by do |rec|
        [rec.distribute_group_index]
      end

      volume.distribute_groups = dist_grp_data.map do |_, rows2|
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

      volume
    end
  end

  private def volumes_query
    "SELECT volumes.id AS id,
            volumes.name AS name,
            volumes.state AS state,
            volumes.snapshot_plugin AS snapshot_plugin,
            volumes.type AS type,
            volumes.options AS options,
            volumes.size_bytes AS size_bytes,
            volumes.inodes_count AS inodes_count,
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
            storage_units.inodes_count AS storage_unit_inodes_count,
            pools.id AS pool_id,
            pools.name AS pool_name
     FROM volumes
     INNER JOIN distribute_groups ON volumes.id = distribute_groups.volume_id
     INNER JOIN storage_units ON storage_units.volume_id = volumes.id AND storage_units.distribute_group_id = distribute_groups.id
     INNER JOIN nodes ON nodes.id = storage_units.node_id
     INNER JOIN pools ON pools.id = volumes.pool_id
    "
  end

  private def volumes_query_order_by
    " ORDER BY volumes.created_on DESC, distribute_groups.idx ASC, storage_units.idx ASC "
  end

  def list_volumes
    query = volumes_query + volumes_query_order_by
    group_volumes(
      connection.query_all(query, as: VolumeView)
    )
  end

  def list_volumes_by_user(user_id)
    ids = viewable_volume_ids(user_id)
    volumes = list_volumes

    pool_ids = ids.keys

    # If user is having permission to view all Pools
    return volumes if pool_ids.includes?("all")

    # Select the Volumes only if user is having atleast view permission
    # to all Volumes or the selected volumes
    volumes.select! do |volume|
      flag = false
      ids.each do |pool_id, volume_ids|
        if pool_id == volume.pool.id && (volume_ids.includes?("all") || volume_ids.includes?(volume.id))
          flag = true
          break
        end
      end

      flag
    end

    volumes
  end

  def list_volumes_by_user(user_id, pool_id)
    volume_ids = viewable_volume_ids(user_id, pool_id)
    volumes = list_volumes(pool_id)

    # Select the Volumes only if user is having atleast view permission
    # to all Volumes or the selected volumes
    volumes.select! do |volume|
      volume_ids.includes?("all") || volume_ids.includes?(volume.id)
    end

    volumes
  end

  def list_volumes(pool_name)
    query = volumes_query + " WHERE pools.name = ?" + volumes_query_order_by
    group_volumes(
      connection.query_all(query, pool_name, as: VolumeView)
    )
  end

  def get_volume(pool_name, volume_name)
    query = volumes_query + " WHERE pools.name = ? AND volumes.name = ? " + volumes_query_order_by
    volumes = group_volumes(
      connection.query_all(query, pool_name, volume_name, as: VolumeView)
    )

    volumes.size > 0 ? volumes[0] : nil
  end

  def create_volume(pool_id, volume)
    volume_query = insert_query(
      "volumes",
      %w[pool_id id name type state snapshot_plugin size_bytes inodes_count]
    )

    dist_grp_query = insert_query(
      "distribute_groups",
      %w[pool_id volume_id id idx replica_count arbiter_count disperse_count redundancy_count replica_keyword type size_bytes inodes_count]
    )
    storage_unit_query = insert_query(
      "storage_units",
      %w[id pool_id volume_id distribute_group_id idx node_id port path type fs size_bytes inodes_count]
    )
    connection.transaction do |tx|
      conn = tx.connection

      conn.exec(
        volume_query,
        pool_id,
        volume.id,
        volume.name,
        volume.type,
        volume.state,
        volume.snapshot_plugin,
        volume.metrics.size_bytes,
        volume.metrics.inodes_count
      )

      volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
        grp_id = UUID.random.to_s
        conn.exec(
          dist_grp_query,
          pool_id,
          volume.id,
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
            pool_id,
            volume.id,
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

  def update_volume_options(volume_id, options)
    query = update_query("volumes", ["options"], where: " id = ?")
    connection.exec(query, options, volume_id)
  end

  def update_volume_state(volume_id, state)
    query = update_query("volumes", ["state"], where: " id = ?")
    connection.exec(query, state, volume_id)
  end

  def delete_volume(pool_id, volume_id)
    connection.transaction do |tx|
      conn = tx.connection

      # TODO: Delete the Services

      query = "DELETE FROM storage_units WHERE pool_id = ? AND volume_id = ?"
      conn.exec(query, pool_id, volume_id)

      query = "DELETE FROM distribute_groups WHERE pool_id = ? AND volume_id = ?"
      conn.exec(query, pool_id, volume_id)

      query = "DELETE FROM volumes WHERE pool_id = ? AND id = ?"
      conn.exec(query, pool_id, volume_id)
    end
  end

  def volume_exists_by_id?(pool_id, volume_id)
    query = "SELECT COUNT(id) FROM volumes WHERE pool_id = ? AND id = ?"
    connection.scalar(query, pool_id, volume_id).as(Int64) > 0
  end
end
