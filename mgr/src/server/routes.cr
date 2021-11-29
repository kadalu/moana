require "kemal"

before_all do |env|
  env.response.content_type = "application/json"
end

error 404 do |env|
  env.response.content_type = "application/json"
  {"error": "Invalid URL"}.to_json
end

error 500 do |env, exc|
  env.response.content_type = "application/json"
  {"error": "#{exc}"}.to_json
end
