require "uuid"
require "moana_types"
require "db"
require "sqlite3"

module Datastore
  def backup_to(backup_db_path)
    DB.connect "sqlite3://#{backup_db_path}" do |backup_conn|
      backup_conn = backup_conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{@@rootdir}/meta/kadalu.db" do |conn|
        conn = conn.as(SQLite3::Connection)
        conn.dump(backup_conn)
      end
    end
  end

  def restore_from(backup_db_path)
    DB.connect "sqlite3:///var/lib/kadalu/meta/kadalu.db" do |conn|
      conn = conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{backup_db_path}" do |backup_conn|
        backup_conn = backup_conn.as(SQLite3::Connection)
        backup_conn.dump(conn)
      end
    end
  end
end
