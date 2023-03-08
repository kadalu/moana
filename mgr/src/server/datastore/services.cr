require "uuid"

require "moana_types"

module Datastore
  def enable_service(node_name, service)
    query = insert_query("services", %w[node_name name unit], replace: true)
    connection.exec(query, node_name, service.id, service.to_json)
  end

  def disable_service(node_name, service)
    query = "DELETE FROM services WHERE node_name = ? AND name = ?"
    connection.exec(query, node_name, service.id)
  end

  def update_service(node_name, service)
    query = update_query("services", %w[unit], where: "node_name = ? AND name = ?")
    connection.exec(query, service.to_json, node_name, service.id)
  end

  def list_services(node_name)
    query = "select unit FROM services WHERE node_name = ?"
    units = connection.query_all(query, node_name, as: String)
    units.map do |unit|
      MoanaTypes::ServiceUnit.from_json(unit)
    end
  end

  def get_service(node_name, svc_name)
    query = "select unit FROM services WHERE node_name = ? AND name = ?"
    unit = connection.query_one(query, node_name, svc_name, as: String)
    MoanaTypes::ServiceUnit.from_json(unit)
  end
end
