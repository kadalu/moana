require "uuid"

require "moana_types"
require "db"

require "../conf"

module Datastore
  def belongs_to_a_pool?
    pool_name = ""

    # Check if the current node is part of
    # any pool. Collect the Pool name from the
    # local data file.
    data_file = Path.new(@@rootdir, "info")
    if File.exists?(data_file)
      local_node_data = LocalNodeData.from_json(File.read(data_file))
      pool_name = local_node_data.pool_name
    end

    pool_name != ""
  end

  private def pool_query_group_by
    " GROUP BY pools.id, pools.name "
  end

  private def pool_query
    # TODO: Add all node fields
    "SELECT pools.id AS id,
            pools.name AS name,
            COUNT(nodes.id) AS nodes_count,
            COUNT(volumes.id) AS volumes_count
     FROM pools
     LEFT OUTER JOIN nodes ON pools.id = nodes.pool_id
     LEFT OUTER JOIN volumes ON pools.id = volumes.pool_id
     "
  end

  private def pool_query_order_by
    " ORDER BY pools.created_on DESC "
  end

  def list_pools
    connection.query_all(pool_query + pool_query_group_by + pool_query_order_by, as: MoanaTypes::Pool)
  end

  def list_pools(user_id)
    pool_ids = viewable_pool_ids(user_id)
    return [] of MoanaTypes::Pool if pool_ids.size == 0

    pools = connection.query_all(pool_query + pool_query_group_by + pool_query_order_by, as: MoanaTypes::Pool)

    return pools if pool_ids.includes?("all")

    pools.select! do |pool|
      pool_ids.includes?(pool.id)
    end

    pools
  end

  def pools_exists?
    query = "SELECT COUNT(id) FROM pools"
    connection.scalar(query).as(Int64) > 0
  end

  def get_pool(pool_name)
    pools = connection.query_all(
      pool_query + " WHERE pools.name = ? " + pool_query_group_by + pool_query_order_by,
      pool_name,
      as: MoanaTypes::Pool)

    pools.size > 0 ? pools[0] : nil
  end

  def get_pool(user_id, pool_name)
    pool_ids = viewable_pool_ids(user_id)
    return nil if pool_ids.size == 0

    pools = connection.query_all(
      pool_query + " WHERE pools.name = ? " + pool_query_group_by + pool_query_order_by,
      pool_name,
      as: MoanaTypes::Pool)

    if pools.size > 0
      return pools[0] if pool_ids.includes?("all")
      return pools[0] if pool_ids.includes?(pools[0].id)
    end

    nil
  end

  def create_pool(pool_name)
    pool_id = UUID.random.to_s
    query = insert_query("pools", %w[id name])
    connection.exec(query, pool_id, pool_name)

    get_pool(pool_name)
  end

  def nodes_in_pool?(pool_id)
    query = "SELECT COUNT(1) FROM nodes WHERE pool_id = ?"
    connection.scalar(query, pool_id).as(Int64) > 0
  end

  def delete_pool(pool_id)
    query = "DELETE FROM pools WHERE id = ?"
    connection.exec(query, pool_id)
  end

  def rename_pool_name(pool_id, new_pool_name)
    query = "UPDATE pools SET name = ? WHERE id = ?"
    connection.exec(query, new_pool_name, pool_id)
  end
end
