require "uuid"

require "kemal"
require "connection_manager"

ws "/ws/:cluster_id" do |socket, env|
  # TODO: Verify Headers
  # env.request.headers["CLUSTER_ID"] and env.request.headers["Authorization"]
  # Use env.request.headers["NODE_ID"] as node identifier
  cluster_id = env.ws_route_lookup.params["cluster_id"]

  if !env.request.headers["X-Node-ID"]?
    # No Node-ID is set, may be a Client. Generate an ID for
    # each Client connection
    node_id = UUID.random.to_s
  else
    node_id = env.request.headers["X-Node-ID"]
  end

  ConnectionManager.manager.add_connection(cluster_id, node_id, socket)

  socket.on_message do |message|
    ConnectionManager.manager.add_task_response(
      cluster_id,
      ConnectionManager::Message.from_json(message),
      node_id
    )
  end

  # Handle disconnection and clean sockets
  socket.on_close do |_|
    ConnectionManager.manager.close_connection(cluster_id, node_id)
  end
end
