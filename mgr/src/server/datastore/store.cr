require "uuid"
require "json"

require "sqlite3"

require "./schemas"

module Datastore
  extend self

  class_property rootdir = ""

  class DatastoreError < Exception
  end

  @@conn : DB::Database | Nil = nil

  def connection
    @@conn.not_nil!
  end

  def init(workdir : String)
    @@rootdir = workdir
    Dir.mkdir_p("#{@@rootdir}/meta")
    @@conn = DB.open("sqlite3://#{@@rootdir}/meta/kadalu.db")
    connection.exec "PRAGMA journal_mode=WAL;"

    # Do not fail immideately if another writer
    # locked the db.
    connection.exec "PRAGMA busy_timeout=5000;"

    # Strict Foreign key checks
    connection.exec "PRAGMA foreign_keys=ON;"

    SCHEMAS.each do |schema|
      connection.exec schema
    end
  end

  def manager_file
    Path.new(@@rootdir, "mgr")
  end

  def agent_file
    Path.new(@@rootdir, "agent")
  end

  def agent?
    File.exists?(agent_file)
  end

  def manager?
    File.exists?(manager_file)
  end

  def set_manager
    # If this is already manager => No op
    return if manager?

    File.touch(manager_file)
  end

  def set_agent
    # If this is already manager => No op
    return if agent?

    File.touch(agent_file)
  end
end
