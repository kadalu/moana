require "uuid"

require "moana_types"

module Datastore
  def port_available?(node_id : String, port : Int32)
    active = active_ports(node_id)
    reserved = reserved_ports(node_id)
    !active.includes?(port) && !reserved.includes?(port)
  end

  def free_port(node_id : String)
    delete_expired_ports(node_id)
    active = active_ports(node_id)
    reserved = reserved_ports(node_id)
    (49252..49452).find do |p|
      !active.includes?(p) && !reserved.includes?(p)
    end
  end

  def active_ports(node_id : String)
    query = "SELECT port FROM storage_units WHERE node_id = ?"
    connection.query_all(query, node_id, as: Int32)
  end

  def reserved_ports(node_id : String)
    query = "SELECT port FROM ports WHERE node_id = ?"
    connection.query_all(query, node_id, as: Int32)
  end

  def reserve_port(node_id : String, port : Int32)
    query = insert_query("ports", %w[node_id port])
    connection.exec(query, node_id, port)

    port
  end

  def delete_expired_ports(node_id : String)
    query = "DELETE FROM ports WHERE node_id = ? AND updated_on < datetime('now', '-5 minutes')"
    connection.exec(query, node_id)
  end

  def delete_reserved_ports(distribute_groups : Array)
    distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        query = "DELETE FROM ports WHERE node_id = ? AND port = ?"
        connection.exec(query, storage_unit.node.id, storage_unit.port)
      end
    end
  end
end
