require "json"

require "kemal"

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

class AuthHeaderHandler < Kemal::Handler
  def call(env)
    # Verify if X-User-ID and Authorization headers are set.
    # Else, pass it to next Handler without doing anything
    user_id = env.request.headers["X-User-ID"]?
    auth = env.request.headers["Authorization"]?
    if !user_id.nil? && !auth.nil?
      parts = auth.split(" ")
      if parts.size == 2 && parts[0].downcase == "bearer"
        env.set("app_token", parts[1])
        env.set("user_id", user_id)
        env.set("auth_valid?", MoanaDB.valid_token?(user_id, parts[1]))
      end
    end

    # Call next as usual, if a route needs Auth then it checks env.get "auth_valid?"
    call_next env
  end
end

class AuthHandler < Kemal::Handler
  exclude ["/api/v1/users", "/api/v1/apps"], "POST"

  def call(env)
    return call_next(env) if exclude_match?(env) || env.get?("auth_valid?")

    env.response.status_code = 401
    {error: "Unauthorized. Invalid X-User-ID or Authorization header"}.to_json
  end
end

# Set the content type for all APIs
before_all do |env|
  env.response.content_type = "application/json"
end

error 404 do |env|
  {"error": "Not Found"}.to_json
end

MoanaDB.init(".")

add_handler AuthHeaderHandler.new
add_handler AuthHandler.new

# All the routes are set by respective controllers,
# Start the server.
Kemal.run
