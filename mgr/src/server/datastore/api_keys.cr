module Datastore
  def valid_api_key?(user_id, token)
    # Update the api_keys table instead of SELECT!
    # Because it helps to record last accessed time for the App. That may be
    # used to cleanup the rows if it is not accessed for weeks/months etc.
    token_hash = hash_sha256(token)

    query = "UPDATE api_keys SET accessed_on = datetime() WHERE user_id = ? AND token_hash = ?"
    res = connection.exec(query, user_id, token_hash)
    res.rows_affected > 0
  end

  def create_api_key(user_id, name, token)
    api_key_id = UUID.random.to_s
    query = insert_query("api_keys", %w[id user_id name token token_hash])
    token_hash = hash_sha256(token)

    name = token[0...7] if name == ""
    connection.exec(query, api_key_id, user_id, name, token[0...7], token_hash)
    api_key = MoanaTypes::ApiKey.new
    api_key.user_id = user_id
    api_key.id = api_key_id
    api_key.name = name
    api_key.token = token

    api_key
  end

  def list_api_keys(user_id)
    query = "SELECT id, name, token FROM api_keys WHERE user_id = ?"
    keys = connection.query_all(query, user_id, as: {String, String, String})
    keys.map do |key|
      api_key = MoanaTypes::ApiKey.new
      api_key.user_id = user_id
      api_key.id = key[0]
      api_key.name = key[1]
      api_key.token = key[2]

      api_key
    end
  end

  def delete_api_key(user_id, api_key_id)
    query = "DELETE FROM api_keys WHERE user_id = ? AND id = ?"
    connection.exec(query, user_id, api_key_id)
  end

  def delete_unused_api_keys
    query = "DELETE FROM api_keys WHERE accessed_at < datetime('now', '-1 weeks')"
    connection.exec(query)
  end

  def delete_unused_apps(user_id : String)
    query = "DELETE FROM api_keys WHERE user_id = ? AND accessed_at < datetime('now', '-1 weeks')"
    connection.exec(query, user_id)
  end
end
