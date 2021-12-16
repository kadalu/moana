require "uuid"
require "json"

module Datastore
  class_property rootdir = ""

  class DatastoreError < Exception
  end

  def self.manager_file
    Path.new(@@rootdir, "mgr")
  end

  def self.agent_file
    Path.new(@@rootdir, "agent")
  end

  def self.agent?
    File.exists?(agent_file)
  end

  def self.manager?
    File.exists?(manager_file)
  end

  def self.set_manager
    # If this is already manager => No op
    return if manager?

    File.touch(manager_file)
  end

  def self.set_agent
    # If this is already manager => No op
    return if agent?

    File.touch(agent_file)
  end
end
