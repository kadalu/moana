require "uuid"

require "moana_types"

module Datastore
  def enable_service(node_id, service)
    query = insert_query("services", %w[node_id name unit], replace: true)
    connection.exec(query, node_id, service.id, service.to_json)
  end

  def disable_service(node_id, service)
    query = "DELETE FROM services WHERE node_id = ? AND name = ?"
    connection.exec(query, node_id, service.id)
  end

  def update_service(node_id, service)
    query = update_query("services", %w[unit], where: "node_id = ? AND name = ?")
    connection.exec(query, service.to_json, node_id, service.id)
  end

  def list_services(node_id)
    query = "select unit FROM services WHERE AND node_id = ?"
    units = connection.query_all(query, node_id, as: String)
    units.map do |unit|
      MoanaTypes::ServiceUnit.from_json(unit)
    end
  end

  def get_service(node_id, svc_name)
    query = "select unit FROM services WHERE node_id = ? AND name = ?"
    unit = connection.query_one(query, node_id, svc_name, as: String)
    MoanaTypes::ServiceUnit.from_json(unit)
  end
end
