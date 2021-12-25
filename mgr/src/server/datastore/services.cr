require "uuid"

require "moana_types"

module Datastore
  def enable_service(pool_id, node_id, service)
    query = insert_query("services", %w[pool_id node_id name unit])
    connection.exec(query, pool_id, node_id, service.id, service.to_json)
  end

  def disable_service(pool_id, node_id, service)
    query = "DELETE FROM services WHERE pool_id = ? AND node_id = ? AND name = ?"
    connection.exec(query, pool_id, node_id, service.id)
  end

  def list_services(pool_id, node_id)
    query = "select unit FROM services WHERE pool_id = ? AND node_id = ?"
    units = connection.query_all(query, pool_id, node_id, as: String)
    units.map do |unit|
      MoanaTypes::ServiceUnit.from_json(unit)
    end
  end

  def get_service(pool_id, node_id, svc_name)
    query = "select unit FROM services WHERE pool_id = ? AND node_id = ? AND name = ?"
    unit = connection.query_one(query, pool_id, node_id, svc_name, as: String)
    MoanaTypes::ServiceUnit.from_json(unit)
  end
end
