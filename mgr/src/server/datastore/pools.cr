require "uuid"

require "moana_types"
require "db"

require "../conf"

# WORKDIR/
#   - pools/
#       - mypool/
#           - info
module Datastore
  struct PoolView
    include DB::Serializable

    # TODO: Add all node fields
    property id = "", name = "", node_id = "", node_name = "", node_endpoint = ""
  end

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

  private def pool_query
    # TODO: Add all node fields
    "SELECT pools.id AS id,
            pools.name AS name,
            nodes.id AS node_id,
            nodes.name AS node_name,
            nodes.endpoint AS node_endpoint
     FROM pools
     LEFT OUTER JOIN nodes ON pools.id = nodes.pool_id
     "
  end

  private def pool_query_order_by
    " ORDER BY pools.created_on DESC, nodes.created_on DESC "
  end

  private def group_pools(pools)
    grouped_data = pools.group_by do |rec|
      [rec.id, rec.name]
    end

    grouped_data.map do |_, rows|
      pool = MoanaTypes::Pool.new
      pool.id = rows[0].id
      pool.name = rows[0].name

      # Left outer Join, Node details may be nil if
      # no nodes joined the Pool
      rows = rows.select { |row| !row.node_id.nil? }

      pool.nodes = rows.map do |row|
        node = MoanaTypes::Node.new
        node.id = row.node_id
        node.name = row.node_name
        node.endpoint = row.node_endpoint

        node
      end

      pool
    end
  end

  def list_pools
    group_pools(connection.query_all(pool_query + pool_query_order_by, as: PoolView))
  end

  def list_pools(user_id)
    pool_ids = viewable_pool_ids(user_id)
    return [] of MoanaTypes::Pool if pool_ids.size == 0

    pools = group_pools(connection.query_all(pool_query + pool_query_order_by, as: PoolView))

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
    pools = group_pools(connection.query_all(
      pool_query + " WHERE pools.name = ? " + pool_query_order_by,
      pool_name,
      as: PoolView))

    pools.size > 0 ? pools[0] : nil
  end

  def create_pool(pool_name)
    pool_id = UUID.random.to_s
    query = insert_query("pools", %w[id name])
    connection.exec(query, pool_id, pool_name)

    get_pool(pool_name)
  end
end
