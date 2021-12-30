require "kemal"

require "../datastore/*"

# Create a User
post "/api/v1/users" do |env|
  name = env.params.json["name"].as(String)
  username = env.params.json["username"].as(String)
  password = env.params.json["password"].as(String)

  if Datastore.user_exists?(username)
    halt(env, status_code: 400, response: ({"error": "User already exists"}).to_json)
  end

  # TODO: Validate Username and Name
  env.response.status_code = 201
  Datastore.create_user(username, name, password).to_json
end

# Delete a User
delete "/api/v1/users/:username" do |env|
  username = env.params.url["username"]

  unless Datastore.user_exists?(username)
    halt(env, status_code: 400, response: ({"error": "User does not exists"}).to_json)
  end

  Datastore.delete_user_by_username(username)
end

# # Create a User role
# post "/api/v1/users/:username/roles" do |env|
#   username = env.params.url["username"]
#   pool_name = env.params.json["pool_name"].as(String)
#   volume_name = env.params.json["volume_name"].as(String)
#   role = env.params.json["role"].as(String)

#   unless Datastore.user_exists?(username)
#     halt(env, status_code: 400, response: ({"error": "User does not exists"}).to_json)
#   end

#   Datastore.create_role(username, pool_name, volume_name, role)
# end

# # Delete a User role
# delete "/api/v1/users/:username/roles/:pool_name/:volume_name/:role_name" do |env|
#   username = env.params.url["username"]
#   pool_name = env.params.url["pool_name"]
#   volume_name = env.params.url["volume_name"]
#   role = env.params.url["role_name"]

#   Datastore.delete_role(username, pool_name, volume_name, role)
#   env.response.status_code = 204
# end

# Users list
get "/api/v1/users" do |env|
  unless Datastore.super_admin?(env.user_id)
    halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
  end

  Datastore.list_users.to_json
end

# Get User
get "/api/v1/users/:username" do |env|
  username = env.params.url["username"]
  if !Datastore.super_admin?(env.user_id) && env.user_id != username
    halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
  end

  Datastore.get_user(username).to_json
end

# # Get User roles
# post "/api/v1/users/:username/roles" do |env|
#   username = env.params.url["username"]
#   if !Datastore.super_admin?(env.user_id) && env.user_id != username
#     halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
#   end

#   Datastore.list_roles(env.user_id).to_json
# end

# Get Pool users
get "/api/v1/pools/:pool_name/users" do |env|
  pool_name = env.params.url["pool_name"]
  if !Datastore.admin?(env.user_id, pool_name)
    halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
  end

  Datastore.list_users(pool_name).to_json
end

# Get Volume users
get "/api/v1/pools/:pool_name/volumes/:volume_name/users" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]
  if !Datastore.admin?(env.user_id, pool_name, volume_name)
    halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
  end

  Datastore.list_users(pool_name, volume_name).to_json
end

post "/api/v1/users/:username/api-keys" do |env|
  username = env.params.url["username"]
  password = env.params.json["password"].as(String)

  user = Datastore.get_user(username)

  if user.nil?
    halt(env, status_code: 400, response: ({"error": "User doesn't exists"}).to_json)
  end

  unless Datastore.valid_user?(user.id, password)
    halt(env, status_code: 403, response: ({"error": "Invalid username or password"}).to_json)
  end

  env.response.status_code = 201
  name = "Login"
  token = hash_sha256(UUID.random.to_s)
  Datastore.create_api_key(user.id, name, token).to_json
end

# Create a API Key. Similar to the above API
# but this works only when a user is logged in
# or authorized using the API key.
post "/api/v1/api-keys" do |env|
  name = env.params.json["name"].as(String)
  token = hash_sha256(UUID.random.to_s)
  env.response.status_code = 201
  Datastore.create_api_key(env.user_id, name, token).to_json
end

# Delete a API Key
delete "/api/v1/api-keys/:api_key_id" do |env|
  api_key_id = env.params.url["api_key_id"]
  Datastore.delete_api_key(env.user_id, api_key_id)
  env.response.status_code = 204
end

# List API Keys
get "/api/v1/api-keys" do |env|
  Datastore.list_api_keys(env.user_id).to_json
end
