module Datastore
  def viewable_pool_ids(user_id)
    query = "SELECT DISTINCT pool_id FROM roles WHERE user_id = ?"
    connection.query_all(query, user_id, as: String)
  end

  def viewable_volume_ids(user_id)
    query = "SELECT DISTINCT pool_id, volume_id FROM roles WHERE user_id = ?"
    data = connection.query_all(query, user_id, as: {String, String})
    data.group_by &.pool_id
  end

  def viewable_volume_ids(user_id, pool_id)
    query = "SELECT DISTINCT volume_id FROM roles WHERE user_id = ? AND pool_id = ?"
    connection.query_all(query, user_id, as: String)
  end

  def role?(user_id, pool_name, volume_name, roles)
    # If pool_name is "all" then do not join the pools table
    # Similarly do not join volumes table if the volume name is "all"
    query = "SELECT COUNT(1) FROM roles "
    params = [] of DB::Any
    params << user_id
    where = " WHERE roles.user_id = ? "

    if pool_name == "all"
      where += " AND roles.pool_id = ? "
    else
      query += " INNER JOIN pools ON roles.pool_id = pools.id "
      where += " AND pools.name = ? "
    end
    params << pool_name

    if volume_name == "all"
      where += " AND roles.volume_id = ? "
    else
      query += " INNER JOIN volumes ON roles.volume_id = volumes.id "
      where += " AND volumes.name = ? "
    end
    params << volume_name

    roles_list = (roles.map { |_| "?" }).join(",")
    where += " AND roles.name IN (#{roles_list})"
    params += roles

    connection.scalar(query + where, args: params).as(Int64) > 0
  end

  def viewer?(user_id, pool_name, volume_name)
    viewer?(user_id, pool_name) ||
      role?(user_id, pool_name, volume_name, ["viewer", "maintainer", "admin"])
  end

  def viewer?(user_id, pool_name)
    viewer?(user_id) ||
      role?(user_id, pool_name, "all", ["viewer", "maintainer", "admin"])
  end

  def viewer?(user_id)
    role?(user_id, "all", "all", ["viewer", "maintainer", "admin"])
  end

  def maintainer?(user_id, pool_name, volume_name)
    maintainer?(user_id, pool_name) ||
      role?(user_id, pool_name, volume_name, ["maintainer", "admin"])
  end

  def maintainer?(user_id, pool_name)
    maintainer?(user_id) ||
      role?(user_id, pool_name, "all", ["maintainer", "admin"])
  end

  def maintainer?(user_id)
    role?(user_id, "all", "all", ["maintainer", "admin"])
  end

  def admin?(user_id, pool_name, volume_name)
    admin?(user_id, pool_name) ||
      role?(user_id, pool_name, volume_name, ["admin"])
  end

  def admin?(user_id, pool_name)
    admin?(user_id) ||
      role?(user_id, pool_name, "all", ["admin"])
  end

  def admin?(user_id)
    role?(user_id, "all", "all", ["admin"])
  end

  def client?(user_id, pool_name, volume_name)
    client?(user_id, pool_name) ||
      role?(user_id, pool_name, volume_name, ["client", "maintainer", "admin"])
  end

  def client?(user_id, pool_name)
    client?(user_id) ||
      role?(user_id, pool_name, "all", ["client", "maintainer", "admin"])
  end

  def client?(user_id)
    role?(user_id, "all", "all", ["client", "maintainer", "admin"])
  end

  def create_role(user_id, pool_id, volume_id, role)
    query = insert_query("roles", %w[user_id pool_id volume_id name])
    connection.exec(query, user_id, pool_id, volume_id, role)
  end

  def delete_role(user_id, pool_id, volume_id, role)
    query = "DELETE FROM roles WHERE user_id = ? AND pool_id = ? AND volume_id = ? AND name = ?"
    connection.exec(query, user_id, pool_id, volume_id, role)
  end

  def list_roles(user_id)
    query = "SELECT pool_id, volume_id, name FROM roles WHERE user_id = ?"
    roles = connection.query_all(query, user_id, as: {String, String, String})
    roles.map do |row|
      role = MoanaTypes::Role.new
      role.pool_id = row[0]
      role.volume_id = row[1]
      role.role = row[2]

      role
    end
  end
end
