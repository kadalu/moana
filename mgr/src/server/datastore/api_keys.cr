module Datastore
  def self.valid_api_key?(user_id, token)
    # Update the api_keys table instead of SELECT!
    # Because it helps to record last accessed time for the App. That may be
    # used to cleanup the rows if it is not accessed for weeks/months etc.
    token_hash = hash_sha256(token)

    query = "UPDATE api_keys SET accessed_on = datetime() WHERE user_id = ? AND token_hash = ?"
    res = connection.exec(query, user_id, token_hash)
    res.rows_affected > 0
  end

  def self.create_api_key(user_id, name, token)
    query = insert_query("api_keys", %w[user_id name token token_hash])
    token_hash = hash_sha256(token)

    connection.exec(query, user_id, name, token[0...7], token_hash)
  end

  def self.list_api_keys(user_id)
    query = "SELECT name, token FROM api_keys WHERE user_id = ?"
    keys = connection.query_all(query, user_id, as: {String, String})
    keys.map do |key|
      {"name" => key[0], "token" => key[1]}
    end
  end

  def self.delete_api_key(user_id : String, name : String)
    query = "DELETE FROM api_keys WHERE user_id = ? AND name = ?"
    connection.exec(query, user_id, name)
  end

  def self.delete_unused_api_keys
    query = "DELETE FROM api_keys WHERE accessed_at < datetime('now', '-1 weeks')"
    connection.exec(query)
  end

  def self.delete_unused_apps(user_id : String)
    query = "DELETE FROM api_keys WHERE user_id = ? AND accessed_at < datetime('now', '-1 weeks')"
    connection.exec(query, user_id)
  end
end
