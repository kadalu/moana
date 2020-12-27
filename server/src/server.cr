require "json"

require "kemal"

# Set the content type for all APIs
before_all do |env|
  env.response.content_type = "application/json"
end

error 404 do |env|
  {"error": "Not Found"}.to_json
end

# All the routes are set by respective controllers,
# Start the server.
Kemal.run
