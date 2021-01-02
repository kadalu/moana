require "openssl"

require "kemal"

require "./db/*"

get "/api/v1/users/:user_id" do |env|
  user = MoanaDB.get_user(env.params.url["user_id"])

  if user.nil?
    env.response.status_code = 400
    {"error": "Invalid User ID"}.to_json
  else
    user.to_json
  end
end

post "/api/v1/users" do |env|
  name = env.params.json["name"].as(String)
  email = env.params.json["email"].as(String)
  password = env.params.json["password"].as(String)

  password_hash = OpenSSL::Digest.new("SHA256")
  password_hash.update(password)

  env.response.status_code = 201
  MoanaDB.create_user(name, email, password_hash.hexdigest).to_json
end

delete "/api/v1/users/:user_id" do |env|
  # TODO: Only Admin or Self can delete a User
  MoanaDB.delete_user(env.params.url["user_id"])

  env.response.status_code = 204
  nil
end
