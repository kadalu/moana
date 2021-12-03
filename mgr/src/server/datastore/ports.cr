require "uuid"

require "moana_types"

module Datastore
  def self.reserved_ports_dir(pool_name, node_name)
    Path.new(@@rootdir, "pools", pool_name, "ports", node_name, "reserved")
  end

  def self.active_ports_dir(pool_name, node_name)
    Path.new(@@rootdir, "pools", pool_name, "ports", node_name, "active")
  end

  def self.reserved_port_file(pool_name, node_name, port)
    Path.new(reserved_ports_dir(pool_name, node_name), "#{port}")
  end

  def self.active_port_file(pool_name, node_name, port)
    Path.new(active_ports_dir(pool_name, node_name), "#{port}")
  end

  def self.port_active?(pool_name, node_name, port)
    File.exists?(active_port_file(pool_name, node_name, port))
  end

  def self.port_reserved?(pool_name, node_name, port)
    File.exists?(reserved_port_file(pool_name, node_name, port))
  end

  def self.reserve_port(pool_name, node_name, port)
    Dir.mkdir_p(reserved_ports_dir(pool_name, node_name))
    File.touch(reserved_port_file(pool_name, node_name, port))
  end

  def self.activate_port(pool_name, node_name, port)
    Dir.mkdir_p(active_ports_dir(pool_name, node_name))
    File.rename(
      reserved_port_file(pool_name, node_name, port),
      active_port_file(pool_name, node_name, port)
    )
  end
end
