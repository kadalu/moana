require "uuid"

require "moana_types"

module Datastore
  def self.reserved_ports_dir(cluster_name, node_name)
    Path.new(@@rootdir, "clusters", cluster_name, "ports", node_name, "reserved")
  end

  def self.active_ports_dir(cluster_name, node_name)
    Path.new(@@rootdir, "clusters", cluster_name, "ports", node_name, "active")
  end

  def self.reserved_port_file(cluster_name, node_name, port)
    Path.new(reserved_ports_dir(cluster_name, node_name), "#{port}")
  end

  def self.active_port_file(cluster_name, node_name, port)
    Path.new(active_ports_dir(cluster_name, node_name), "#{port}")
  end

  def self.port_active?(cluster_name, node_name, port)
    File.exists?(active_port_file(cluster_name, node_name, port))
  end

  def self.port_reserved?(cluster_name, node_name, port)
    File.exists?(reserved_port_file(cluster_name, node_name, port))
  end

  def self.reserve_port(cluster_name, node_name, port)
    Dir.mkdir_p(reserved_ports_dir(cluster_name, node_name))
    File.touch(reserved_port_file(cluster_name, node_name, port))
  end

  def self.activate_port(cluster_name, node_name, port)
    Dir.mkdir_p(active_ports_dir(cluster_name, node_name))
    File.rename(
      reserved_port_file(cluster_name, node_name, port),
      active_port_file(cluster_name, node_name, port)
    )
  end
end
