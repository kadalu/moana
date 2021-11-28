require "uuid"

require "moana_types"

module Datastore
  def self.services_dir(cluster_name, node_name)
    Path.new(@@rootdir, "clusters", cluster_name, "services", node_name)
  end

  def self.service_file(cluster_name, node_name, service_id)
    Path.new(services_dir(cluster_name, node_name), service_id)
  end

  def self.enable_service(cluster_name, node_name, service)
    Dir.mkdir_p(services_dir(cluster_name, node_name))
    File.write(service_file(cluster_name, node_name, service.id), service.to_json)
  end

  def self.disable_service(cluster_name, node_name, service)
    File.remove(service_file(cluster_name, node_name, service.id))
  end
end
