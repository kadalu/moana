require "json"

require "kemal"

require "./db/db"
require "./cluster_routes"
require "./node_routes"
require "./task_routes"
require "./volume_routes"
require "./option_routes"
require "./volfile_routes"

# Set the content type for all APIs
before_all do |env|
  env.response.content_type = "application/json"
end

error 404 do |env|
  {"error": "Not Found"}.to_json
end

MoanaDB.init(".")

# All the routes are set by respective controllers,
# Start the server.
Kemal.run
