require "uuid"
require "moana_types"
require "db"
require "sqlite3"

module Datastore
  def dump(from_db, to_db)
    DB.connect "sqlite3://#{to_db}" do |to_conn|
      to_conn = to_conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{from_db}" do |from_conn|
        from_conn = from_conn.as(SQLite3::Connection)
        from_conn.dump(to_conn)
      end
    end
  end
end
