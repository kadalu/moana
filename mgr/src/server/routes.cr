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

def unauthorized(env, message)
  env.response.status_code = 401
  env.response.content_type = "application/json"
  env.response.print ({"error": "Unauthorized. #{message}"}).to_json
end

class AuthHandler < Kemal::Handler
  exclude ["/api/v1/users", "/api/v1/users/:username/api-keys"], "POST"

  def call(env)
    return call_next(env) if exclude_match?(env)

    user_id = env.request.headers["X-UserID"]?
    auth = env.request.headers["Authorization"]?

    return unauthorized(env, "X-User_id is not set") if !user_id.nil?
    return unauthorized(env, "Authorization is not set") if auth.nil?

    bearer, _, token = auth.partition(" ")
    if bearer.downcase != "bearer" || token == ""
      return unauthorized(env, "Invalid Authoriation header")
    end

    return unauthorized(env, "Invalid credentials") unless Datastore.valid_api_key?(user_id, token)

    env.set("user_id", user_id)

    call_next(env)
  end
end
