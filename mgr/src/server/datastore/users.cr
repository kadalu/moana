require "db"

module Datastore
  struct UserView
    include DB::Serializable

    property id = "", username = "", name = "", pool_id = "", volume_id = "", role = ""
  end

  private def user_select_query
    "SELECT users.id AS id,
            users.username AS username,
            users.name AS name,
            roles.pool_id AS pool_id,
            roles.volume_id AS volume_id,
            roles.name AS role
     FROM users"
  end

  private def group_users(users)
    grouped_data = users.group_by &.id
    grouped_data.map do |_, rows|
      user = MoanaTypes::User.new
      user.id = rows[0].id
      user.username = rows[0].username
      user.name = rows[0].name
      rows = rows.reject! { |v| v.nil? }

      user.roles = rows.map do |row|
        role = MoanaTypes::Role.new
        role.pool_id = row.pool_id
        role.volume_id = row.volume_id
        role.user_id = row.id
        role.role = row.role

        role
      end

      user
    end
  end

  def list_users
    group_users(connection.query_all(user_select_query + left_outer_join_roles, as: UserView))
  end

  def list_users(pool_id)
    query = user_select_query + inner_join_roles + " WHERE roles.pool_id = ?"
    group_users(connection.query_all(query, pool_id, as: UserView))
  end

  private def left_outer_join_roles
    " LEFT OUTER JOIN roles ON users.id = roles.user_id "
  end

  private def inner_join_roles
    " INNER JOIN roles ON users.id = roles.user_id "
  end

  def list_users(pool_id, volume_id)
    query = user_select_query + inner_join_roles + " WHERE roles.pool_id = ? AND roles.volume_id = ?"
    group_users(connection.query_all(query, pool_id, as: UserView))
  end

  def user_exists?(username)
    query = "SELECT COUNT(id) FROM users WHERE username = ?"
    connection.scalar(query, username).as(Int64) > 0
  end

  def get_user(username)
    query = user_select_query + left_outer_join_roles + " WHERE users.username = ?"
    users = group_users(connection.query_all(query, username, as: UserView))
    users.size > 0 ? users[0] : nil
  end

  def get_user_by_id(user_id)
    query = user_select_query + left_outer_join_roles + " WHERE users.id = ?"
    users = group_users(connection.query_all(query, user_id, as: UserView))
    users.size > 0 ? users[0] : nil
  end

  def valid_user?(user_id, password)
    password_hash = hash_sha256(password)
    # Update the users table instead of SELECT!
    # Because it helps to record last accessed time for the User.

    query = "UPDATE users SET accessed_on = datetime() WHERE id = ? AND password_hash = ?"
    res = connection.exec(query, user_id, password_hash)
    res.rows_affected > 0
  end

  def create_user(username, name, password)
    password_hash = hash_sha256(password)
    user_id = UUID.random.to_s
    query = insert_query("users", %w[id username name password_hash])

    connection.transaction do |tx|
      conn = tx.connection

      first_user = zero_users?
      conn.exec(query, user_id, username, name, password_hash)

      # First user becomes super admin
      if first_user
        roles_query = insert_query("roles", %w[user_id pool_id volume_id name])
        conn.exec(roles_query, user_id, "all", "all", "admin")
      end
    end

    get_user(username)
  end

  def set_user_password(user_id, password)
    password_hash = hash_sha256(password)
    query = update_query("users", ["password_hash"], where: "id = ?")
    connection.exec(query, password_hash, user_id)
  end

  def delete_user_by_username(username)
    query = "DELETE FROM users WHERE username = ?"
    connection.exec(query, username)
  end

  def zero_users?
    connection.scalar("SELECT COUNT(1) FROM users LIMIT 1").as(Int64) == 0
  end
end
