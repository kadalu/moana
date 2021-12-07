require "uuid"

require "moana_types"

module Datastore
  def self.services_dir(pool_name, node_name)
    Path.new(@@rootdir, "pools", pool_name, "services", node_name)
  end

  def self.service_file(pool_name, node_name, service_id)
    Path.new(services_dir(pool_name, node_name), service_id)
  end

  def self.enable_service(pool_name, node_name, service)
    Dir.mkdir_p(services_dir(pool_name, node_name))
    File.write(service_file(pool_name, node_name, service.id), service.to_json)
  end

  def self.disable_service(pool_name, node_name, service)
    File.delete(service_file(pool_name, node_name, service.id))
  end

  def self.list_services(pool_name, node_name)
    services = [] of MoanaTypes::ServiceUnit

    svc_dir = services_dir(pool_name, node_name)
    return services unless File.exists?(svc_dir)

    Dir.children(svc_dir).each do |svc_name|
      services << get_service(pool_name, node_name, svc_name).not_nil!
    end

    services
  end

  def self.get_service(pool_name, node_name, svc_name)
    service_file_path = service_file(pool_name, node_name, svc_name)
    return nil unless File.exists?(service_file_path)

    MoanaTypes::ServiceUnit.from_json(File.read(service_file_path).strip)
  end
end
