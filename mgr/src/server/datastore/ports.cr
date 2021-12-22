require "uuid"

require "moana_types"

module Datastore
  def self.port_available?(pool_id : String, node_id : String, port : Int32)
    active = active_ports(pool_id, node_id)
    reserved = reserved_ports(pool_id, node_id)
    !active.includes?(port) && !reserved.includes?(port)
  end

  def self.free_port(pool_id : String, node_id : String)
    delete_expired_ports(pool_id, node_id)
    active = active_ports(pool_id, node_id)
    reserved = reserved_ports(pool_id, node_id)
    (49252..49452).find do |p|
      !active.includes?(p) && !reserved.includes?(p)
    end
  end

  def self.active_ports(pool_id : String, node_id : String)
    query = "SELECT port FROM storage_units WHERE pool_id = ? AND node_id = ?"
    connection.query_all(query, pool_id, node_id, as: Int32)
  end

  def self.reserved_ports(pool_id : String, node_id : String)
    query = "SELECT port FROM ports WHERE pool_id = ? AND node_id = ?"
    connection.query_all(query, pool_id, node_id, as: Int32)
  end

  def self.reserve_port(pool_id : String, node_id : String, port : Int32)
    query = insert_query("ports", %w[pool_id node_id port])
    connection.exec(query, pool_id, node_id, port)

    port
  end

  def self.delete_expired_ports(pool_id : String, node_id : String)
    query = "DELETE FROM ports WHERE pool_id = ? AND node_id = ? AND updated_on < datetime('now', '-5 minutes')"
    connection.exec(query, pool_id, node_id)
  end
end
