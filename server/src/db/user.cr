require "json"
require "uuid"

require "sqlite3"
require "moana_types"

USER_SELECT_QUERY = <<-SQL
  SELECT users.id AS id,
       users.name AS name,
       users.email AS email,
       roles.cluster_id AS role_cluster_id,
       roles.user_id AS role_user_id,
       roles.volume_id AS role_volume_id,
       roles.name AS role_name
  FROM users
  LEFT OUTER JOIN roles
  ON users.id = roles.user_id
SQL

module MoanaDB
  struct UserView
    include DB::Serializable

    property id : String,
             name : String,
             email : String,
             role_cluster_id : String,
             role_user_id : String,
             role_volume_id : String,
             role_name : String
  end

  def self.create_table_users(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS users (
        id            UUID PRIMARY KEY,
        name          VARCHAR,
        email         VARCHAR,
        password_hash VARCHAR,
        created_at    TIMESTAMP,
        updated_at    TIMESTAMP
    );"
  end

  private def self.grouped_users(data : Array(UserView))
    grouped_data = data.group_by do |rec|
      # Group by users.id, users.name, users.email
      # Row index are same as specified in the Query
      [rec.id, rec.name, rec.email]
    end

    grouped_data.map do |key, rows|
      # Select only if node details are not nil
      rows = rows.select { |row| !row.role_name.nil? }

      user = MoanaTypes::User.new(key[0], key[1], key[2])
      user.roles = rows.map do |row|
        MoanaTypes::Role.new(
          row.role_cluster_id.not_nil!,
          row.role_user_id.not_nil!,
          row.role_volume_id.not_nil!,
          row.role_name.not_nil!,
        )
      end

      user
    end
  end

  def self.list_users(conn = @@conn)
    grouped_users(
      conn.not_nil!.query_all(USER_SELECT_QUERY, as: UserView)
    )
  end

  def self.get_user(id : String, conn = @@conn)
    users = grouped_users(
      conn.not_nil!.query_all("#{USER_SELECT_QUERY} WHERE users.id = ?", id, as: UserView)
    )

    return nil if users.size == 0

    users[0]
  end

  def self.create_user(name : String, email : String, password_hash : String, conn = @@conn)
    query = "INSERT INTO users(id, name, email, password_hash, created_at, updated_at)
             VALUES           (?,  ?,    ?,     ?,             datetime(), datetime());"

    user_id = UUID.random.to_s
    conn.not_nil!.exec(
      query,
      user_id,
      name,
      email,
      password_hash
    )

    MoanaTypes::User.new(user_id, name, email)
  end

  def self.update_user(id : String, name : String, conn = @@conn)
    # TODO: Update all required fields
    query = "UPDATE users SET name = ?, updated_at = datetime()
             WHERE id = ?"

    conn.not_nil!.exec(query, name, id)

    get_user(id)
  end

  def self.delete_user(id : String, conn = @@conn)
    conn.not_nil!.transaction do |tx|
      cnn = tx.connection

      # Delete all roles of the user
      delete_role(id, cnn)

      query = "DELETE FROM users WHERE id = ?"
      cnn.exec(query, id)
    end
  end
end
