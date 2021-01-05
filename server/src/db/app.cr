require "json"
require "uuid"

require "sqlite3"
require "moana_types"

require "./helpers"

APP_SELECT_QUERY = <<-SQL
  SELECT id,
         user_id,
         remote_ip,
         user_agent,
         created_at
  FROM apps
  WHERE user_id = ?
SQL

module MoanaDB
  def self.create_table_apps(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS apps (
        id            UUID PRIMARY KEY,
        user_id       UUID,
        token_hash    VARCHAR,
        remote_ip     VARCHAR,
        user_agent    VARCHAR,
        created_at    TIMESTAMP,
        accessed_at   TIMESTAMP,
        updated_at    TIMESTAMP
    );"
  end

  def self.list_apps(user_id : String, conn = @@conn)
    conn.not_nil!.query_all(APP_SELECT_QUERY, as: MoanaTypes::App)
  end

  def self.valid_token?(user_id : String, token : String, conn = @@conn)
    # Update the apps table instead of SELECT!
    # Because it helps to record last accessed time for the App. That may be
    # used to cleanup the rows if it is not accessed for weeks/months etc.
    token_hash = hash_sha256(token)

    query = "UPDATE apps SET accessed_at = datetime() WHERE user_id = ? AND token_hash = ?"
    res = conn.not_nil!.exec(query, user_id, token_hash)
    res.rows_affected > 0
  end

  def self.create_app(user_id : String, token : String, remote_ip : String, user_agent : String, conn = @@conn)
    query = "INSERT INTO apps(id, user_id, token_hash, remote_ip, user_agent, created_at, accessed_at, updated_at)
             VALUES           (?, ?,       ?,          ?,         ?,          datetime(), datetime(),  datetime());"

    token_hash = hash_sha256(token)
    app_id = UUID.random.to_s

    conn.not_nil!.exec(
      query,
      app_id,
      user_id,
      token_hash,
      remote_ip,
      user_agent
    )

    MoanaTypes::App.new(app_id, user_id, token, remote_ip, user_agent)
  end

  def self.delete_app(user_id : String, app_id : String, conn = @@conn)
    query = "DELETE FROM apps WHERE user_id = ? AND id = ?"
    @@conn.not_nil!.exec(query, user_id, app_id)
  end

  def self.delete_unused_apps(conn = @@conn)
    query = "DELETE FROM apps WHERE accessed_at < datetime('now', '-1 weeks')"
    @@conn.not_nil!.exec(query)
  end

  def self.delete_unused_apps(user_id : String, conn = @@conn)
    query = "DELETE FROM apps WHERE user_id = ? AND accessed_at < datetime('now', '-1 weeks')"
    @@conn.not_nil!.exec(query, user_id)
  end
end
