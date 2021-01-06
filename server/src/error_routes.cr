require "kemal"

error 404 do |env|
  {"error": "Not Found"}.to_json
end

error 401 do |env|
  {"error": "Unauthorized"}.to_json
end

error 403 do |env|
  {"error": "Forbidden"}.to_json
end
