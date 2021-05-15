require "json"

require "kemal"
require "connection_manager"

require "./db/db"
require "./cluster_routes"
require "./node_routes"
require "./task_routes"
require "./volume_routes"
require "./option_routes"
require "./volfile_routes"
require "./user_routes"
require "./role_routes"
require "./app_routes"
require "./error_routes"
require "./task_manager"

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

# Set the content type for all APIs
before_all do |env|
  env.response.content_type = "application/json"
end

class AuthHeaderHandler < Kemal::Handler
  def call(env)
    # Verify if X-User-ID and Authorization headers are set.
    # Else, pass it to next Handler without doing anything
    user_id = env.request.headers["X-User-ID"]?
    node_id = env.request.headers["X-Node-ID"]?
    auth = env.request.headers["Authorization"]?

    if !auth.nil?
      parts = auth.split(" ")
      if parts.size == 2 && parts[0].downcase == "bearer"
        env.set("token", parts[1])

        if !user_id.nil?
          # End user APIs
          env.set("user_id", user_id)
          env.set("auth_valid?", MoanaDB.valid_token?(user_id, parts[1]))
        elsif !node_id.nil?
          # Node APIs
          env.set("node_id", node_id)
          env.set("auth_valid?", MoanaDB.valid_node_token?(node_id, parts[1]))
        else
          # May be invite Accept API(Node Join)
          env.set(
            "auth_valid?",
            parts[1] != "-" && MoanaDB.valid_node_invite?(env.params.url["cluster_id"], parts[1])
          )
        end
      end
    end

    # Call next as usual, if a route needs Auth then it checks env.get "auth_valid?"
    call_next env
  end
end

class AuthHandler < Kemal::Handler
  exclude ["/api/v1/users", "/api/v1/apps"], "POST"
  exclude ["/ws/:cluster_id"], "GET"

  def call(env)
    return call_next(env) if exclude_match?(env) || env.get?("auth_valid?")

    env.response.status_code = 401
    env.response.content_type = "application/json"
    env.response.print ({"error": "Unauthorized"}).to_json
  end
end

workdir = ENV.fetch("WORKDIR", "/var/lib/kadalu")
MoanaDB.init(workdir)

connections = ConnectionManager::Manager.new
TaskManager.new(connections)

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

  connections.add_connection(cluster_id, node_id, socket)

  socket.on_message do |message|
    connections.add_task_response(
      cluster_id,
      ConnectionManager::Message.from_json(message),
      node_id
    )
  end

  # Handle disconnection and clean sockets
  socket.on_close do |_|
    connections.close_connection(cluster_id, node_id)
  end
end

add_handler AuthHeaderHandler.new
add_handler AuthHandler.new

# Application name
Kemal.config.app_name = "kadalu-server"

# All the routes are set by respective controllers,
# Start the server.
Kemal.run
