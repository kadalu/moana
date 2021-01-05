require "uuid"
require "kemal"

require "./db/*"
require "./helpers"

post "/api/v1/apps" do |env|
  email = env.params.json["email"].as(String)
  password = env.params.json["password"].as(String)

  user = MoanaDB.get_user(email, password)
  if user
    env.response.status_code = 201
    token = hash_sha256(UUID.random.to_s)

    user_agent = "-"
    user_agent = env.request.headers["User-Agent"] if !env.request.headers["User-Agent"]?.nil?

    remote_address = "-"
    remote_address = "#{env.request.remote_address.not_nil!}" if !env.request.remote_address.nil?

    MoanaDB.create_app(
      user.id,
      token,
      remote_address,
      user_agent
    ).to_json
  else
    env.response.status_code = 400
    {"error": "Invalid User Email or Password"}.to_json
  end
end

get "/api/v1/apps" do |env|
  MoanaDB.list_apps(env.get("user_id").as(String)).to_json
end

delete "/api/v1/apps/:user_id/:app_id" do |env|
  if env.get("user_id") == env.params.url["user_id"]
    MoanaDB.delete_app(env.params.url["user_id"], env.params.url["app_id"])

    env.response.status_code = 204
    nil
  else
    # Trying to delete session/app of some other user
    env.response.status_code = 403

    forbidden_response
  end
end
