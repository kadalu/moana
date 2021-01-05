require "json"
require "uuid"

require "sqlite3"
require "moana_types"

CLUSTER_LIST_QUERY = <<-SQL
  SELECT clusters.id AS id,
       clusters.name AS name,
       nodes.id AS node_id,
       nodes.hostname AS node_hostname,
       nodes.endpoint AS node_endpoint
  FROM clusters
  LEFT OUTER JOIN nodes
  ON clusters.id = nodes.cluster_id
  INNER JOIN roles
  ON clusters.id = roles.cluster_id
SQL

CLUSTER_SELECT_QUERY = <<-SQL
  SELECT clusters.id AS id,
       clusters.name AS name,
       nodes.id AS node_id,
       nodes.hostname AS node_hostname,
       nodes.endpoint AS node_endpoint
  FROM clusters
  LEFT OUTER JOIN nodes
  ON clusters.id = nodes.cluster_id
SQL

module MoanaDB
  struct ClusterView
    include DB::Serializable

    property id : String,
             name : String,
             node_id : String?,
             node_hostname : String?,
             node_endpoint : String?
  end

  def self.create_table_clusters(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS clusters (
        id         UUID PRIMARY KEY,
        name       VARCHAR,
        created_by VARCHAR,
        created_at TIMESTAMP,
        updated_at TIMESTAMP
    );"
  end

  # Cluster ID and name will repeat for each nodes in the Cluster
  # Group these nodes information as nested.
  private def self.grouped_clusters(data : Array(ClusterView))
    grouped_data = data.group_by do |rec|
      # Group by clusters.id, clusters.name
      # Row index are same as specified in the Query
      [rec.id, rec.name]
    end

    grouped_data.map do |key, rows|
      # Select only if node details are not nil
      rows = rows.select { |row| !row.node_id.nil? }

      cluster = MoanaTypes::Cluster.new(key[0], key[1])
      cluster.nodes = rows.map do |row|
        MoanaTypes::Node.new(row.node_id.not_nil!, row.node_hostname.not_nil!, row.node_endpoint.not_nil!)
      end

      cluster
    end
  end

  def self.list_clusters(user_id : String, conn = @@conn)
    query = "#{CLUSTER_LIST_QUERY} WHERE roles.name IN (?, ?, ?) AND user_id = ? AND volume_id = ?"
    params = [] of DB::Any
    params << "admin"
    params << "maintainer"
    params << "viewer"
    params << user_id
    params << "all"

    grouped_clusters(
      conn.not_nil!.query_all(query, args: params, as: ClusterView)
    )
  end

  def self.get_cluster(id : String, conn = @@conn)
    clusters = grouped_clusters(
      conn.not_nil!.query_all("#{CLUSTER_SELECT_QUERY} WHERE clusters.id = ?", id, as: ClusterView)
    )

    return nil if clusters.size == 0

    clusters[0]
  end

  def self.create_cluster(user_id : String, name : String, conn = @@conn)
    query = "INSERT INTO clusters(id, name, created_by, created_at, updated_at)
             VALUES              (?,  ?,    ?,          datetime(), datetime());"

    cluster_id = UUID.random.to_s
    conn.not_nil!.transaction do |tx|
      cnn = tx.connection

      cnn.exec(query, cluster_id, name, user_id)

      # Those who creates Cluster becomes Admin
      create_role(user_id, cluster_id, "all", "admin", conn: cnn)
    end

    MoanaTypes::Cluster.new(cluster_id, name)
  end

  def self.update_cluster(id : String, name : String, conn = @@conn)
    query = "UPDATE clusters SET name = ?, updated_at = datetime()
             WHERE id = ?"

    conn.not_nil!.exec(query, name, id)

    get_cluster(id)
  end

  def self.delete_cluster(id : String, conn = @@conn)
    query = "DELETE FROM clusters WHERE id = ?"
    @@conn.not_nil!.exec(query, id)
  end
end
