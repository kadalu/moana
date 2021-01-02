require "json"
require "uuid"

require "sqlite3"
require "moana_types"

ROLE_SELECT_QUERY = <<-SQL
  SELECT COUNT(id)
  FROM roles
  WHERE cluster_id = ? AND
        volume_id = ? AND
        user_id = ?
SQL

module MoanaDB
  def self.create_table_roles(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS roles (
        cluster_id    UUID,
        volume_id     UUID,
        user_id       UUID,
        name          VARCHAR,
        created_at    TIMESTAMP,
        updated_at    TIMESTAMP,
        PRIMARY KEY(cluster_id, volume_id, user_id, name)
    );"
  end

  private def self.role?(cluster_id : String, user_id : String, volume_id : String, names : Array(String), conn = @@conn)
    values = [] of String
    params : Array(DB::Any) = [cluster_id, user_id, volume_id]
    names.each do |name|
      values << "?"
      params << name
    end

    conn.not_nil!.scalar(
      "#{ROLE_SELECT_QUERY} AND name IN (#{values.join(",")})",
      args: params
    ) > 0
  end

  def self.role_cluster_admin?(cluster_id : String, user_id : String, conn = @@conn)
    role?(cluster_id, user_id, "all", ["admin"], conn)
  end

  def self.role_cluster_maintainer?(cluster_id : String, user_id : String, conn = @@conn)
    role?(cluster_id, user_id, "all", ["admin", "maintainer"], conn)
  end

  def self.role_cluster_viewer?(cluster_id : String, user_id : String, conn = @@conn)
    role?(cluster_id, user_id, "all", ["admin", "maintainer", "viewer"], conn)
  end

  def self.role_cluster_client?(cluster_id : String, user_id : String, conn = @@conn)
    role?(cluster_id, user_id, "all", ["admin", "maintainer", "client"], conn)
  end

  def self.role_volume_admin?(cluster_id : String, user_id : String, volume_id : String, conn = @@conn)
    role?(cluster_id, user_id, volume_id, ["admin"], conn) ||
      role_cluster_maintainer?(cluster_id, user_id, conn)
  end

  def self.role_volume_maintainer?(cluster_id : String, user_id : String, volume_id : String, conn = @@conn)
    role?(cluster_id, user_id, volume_id, ["admin", "maintainer"], conn) ||
      role_cluster_maintainer?(cluster_id, user_id, conn)
  end

  def self.role_volume_viewer?(cluster_id : String, user_id : String, volume_id : String, conn = @@conn)
    role?(cluster_id, user_id, volume_id, ["admin", "maintainer", "viewer"], conn) ||
      role_cluster_viewer?(cluster_id, user_id, conn)
  end

  def self.role_volume_client?(cluster_id : String, user_id : String, volume_id : String, conn = @@conn)
    role?(cluster_id, user_id, volume_id, ["admin", "maintainer", "client"], conn) ||
      role_cluster_client?(cluster_id, user_id, conn)
  end

  def self.create_role(cluster_id : String, user_id : String, volume_id : String, name : String, conn = @@conn)
    query = "INSERT INTO roles(cluster_id, user_id, volume_id, name, created_at, updated_at)
             VALUES           (?,          ?,       ?,         ?,    datetime(), datetime());"

    conn.not_nil!.exec(
      query,
      cluster_id,
      user_id,
      volume_id,
      name
    )

    MoanaTypes::Role.new(cluster_id, user_id, volume_id, name)
  end

  def self.delete_role(user_id : String, conn = @@conn)
    query = "DELETE FROM roles WHERE user_id = ?"
    @@conn.not_nil!.exec(query, user_id)
  end

  def self.delete_role(user_id : String, cluster_id : String, conn = @@conn)
    query = "DELETE FROM roles WHERE user_id = ? AND cluster_id = ?"
    @@conn.not_nil!.exec(query, user_id, cluster_id)
  end

  def self.delete_role(user_id : String, cluster_id : String, volume_id : String, conn = @@conn)
    query = "DELETE FROM roles WHERE user_id = ? AND cluster_id = ? AND volume_id = ?"
    @@conn.not_nil!.exec(query, user_id, cluster_id, volume_id)
  end

  def self.delete_role(user_id : String, cluster_id : String, volume_id : String, name : String, conn = @@conn)
    query = "DELETE FROM roles WHERE user_id = ? AND cluster_id = ? AND volume_id = ?, name = ?"
    @@conn.not_nil!.exec(query, user_id, cluster_id, volume_id, name)
  end
end
