require "kemal"

error 404 do
  {"error": "Not Found"}.to_json
end

error 401 do
  {"error": "Unauthorized"}.to_json
end

error 403 do
  {"error": "Forbidden"}.to_json
end
