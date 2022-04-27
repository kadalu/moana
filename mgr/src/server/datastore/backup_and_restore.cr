require "uuid"
require "moana_types"
require "db"
require "sqlite3"

module Datastore
  def backup(backupdir)
    DB.connect "sqlite3://#{backupdir}/kadalu_backup.db" do |backup_conn|
      backup_conn = backup_conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{@@rootdir}/meta/kadalu.db" do |conn|
        conn = conn.as(SQLite3::Connection)
        conn.dump(backup_conn)
      end
    end
  end

  def restore(backupdir)
    DB.connect "sqlite3://#{@@rootdir}/meta/kadalu.db" do |conn|
      conn = conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{backupdir}" do |backup_conn|
        backup_conn = backup_conn.as(SQLite3::Connection)
        backup_conn.dump(conn)
      end
    end
  end
end
