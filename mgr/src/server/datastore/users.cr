require "db"

module Datastore
  struct UserView
    include DB::Serializable

    property id = "", username = "", name = "", role_pool_id = "", role_volume_id = "", role = ""
  end

  def self.user_select_query
    "SELECT users.id AS id,
            users.username AS username,
            users.name AS name,
            roles.pool_id AS role_pool_id,
            roles.volume_id AS role_volume_id,
            roles.role AS role
     FROM users"
  end

  def self.group_users(users)
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
    end
  end

  def self.list_users
    group_users(connection.query_all(user_select_query + left_outer_join_roles, as: UserView))
  end

  def self.list_users(pool_id)
    query = user_select_query + inner_join_roles + " WHERE roles.pool_id = ?"
    group_users(connection.query_all(query, pool_id, as: UserView))
  end

  def self.left_outer_join_roles
    " LEFT OUTER JOIN roles ON users.id = roles.user_id "
  end

  def self.inner_join_roles
    " INNER JOIN roles ON users.id = roles.user_id "
  end

  def self.list_users(pool_id, volume_id)
    query = user_select_query + inner_join_roles + " WHERE roles.pool_id = ? AND roles.volume_id = ?"
    group_users(connection.query_all(query, pool_id, as: UserView))
  end

  def self.user_exists?(username)
    query = "SELECT COUNT(id) FROM users WHERE username = ?"
    connection.scalar(query, username).as(Int64) > 0
  end

  def self.get_user(username)
    query = user_select_query + left_outer_join_roles + " WHERE users.username = ?"
    group_users(connection.query_all(query, username, as: UserView))
  end

  def self.get_user_by_id(user_id)
    query = user_select_query + left_outer_join_roles + " WHERE users.id = ?"
    group_users(connection.query_all(query, user_id, as: UserView))
  end

  def self.valid_user?(user_id, password)
    password_hash = hash_sha256(password)
    # Update the users table instead of SELECT!
    # Because it helps to record last accessed time for the User.

    query = "UPDATE users SET accessed_on = datetime() WHERE user_id = ? AND password_hash = ?"
    res = connection.exec(query, user_id, password_hash)
    res.rows_affected > 0
  end
end
