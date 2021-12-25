module Datastore
  def self.viewable_pool_ids(user_id)
    query = "SELECT DISTINCT pool_id WHERE user_id = ?"
    connection.query_all(query, user_id, as: String)
  end

  def self.viewable_volume_ids(user_id)
    query = "SELECT DISTINCT pool_id, volume_id WHERE user_id = ?"
    data = connection.query_all(query, user_id, as: {String, String})
    data.group_by &.pool_id
  end

  def self.viewable_volume_ids(user_id, pool_id)
    query = "SELECT DISTINCT volume_id WHERE user_id = ? AND pool_id = ?"
    connection.query_all(query, user_id, as: String)
  end

  def role?(user_id, pool_id, volume_id, roles)
    roles_list = (roles.map { |_| "?" }).join(",")
    query = "SELECT COUNT(*) FROM roles WHERE user_id = ? AND pool_id = ? AND volume_id = ? AND role IN (#{roles_list})"
    connection.scalar(query, user_id, pool_id, volume_id, *roles).as(Int64) > 0
  end

  def self.viewer?(user_id, pool_id, volume_id)
    role?(user_id, pool_id, volume_id, ["viewer", "maintainer", "admin"])
  end

  def self.viewer?(user_id, pool_id)
    role?(user_id, pool_id, "all", ["viewer", "maintainer", "admin"])
  end

  def self.maintainer?(user_id, pool_id, volume_id)
    role?(user_id, pool_id, volume_id, ["maintainer", "admin"])
  end

  def self.maintainer?(user_id, pool_id)
    role?(user_id, pool_id, "all", ["maintainer", "admin"])
  end

  def self.admin?(user_id, pool_id, volume_id)
    role?(user_id, pool_id, volume_id, ["admin"])
  end

  def self.admin?(user_id, pool_id)
    role?(user_id, pool_id, "all", ["admin"])
  end

  def self.client?(user_id, pool_id, volume_id)
    role?(user_id, pool_id, volume_id, ["client", "maintainer", "admin"])
  end

  def self.client?(user_id, pool_id)
    role?(user_id, pool_id, "all", ["client", "maintainer", "admin"])
  end

  def self.create_role(user_id, pool_id, volume_id, role)
    query = insert_query("roles", %w[user_id pool_id volume_id role])
    connection.exec(query, user_id, pool_id, volume_id, role)
  end
end
