require "kemal"

require "../datastore/*"

# Create a User
post "/api/v1/users" do |env|
  name = env.params.json["name"].as(String)
  username = env.params.json["username"].as(String)
  password = env.params.json["password"].as(String)

  api_exception(Datastore.user_exists?(username), ({"error": "User already exists"}).to_json)

  # TODO: Validate Username and Name
  env.response.status_code = 201

  if !Datastore.users_exists?
    Datastore.set_manager
    GlobalConfig.agent = false
  end

  Datastore.create_user(username, name, password).to_json
end

post "/api/v1/users/:username/password" do |env|
  username = env.params.url["username"]
  old_password = env.params.json["password"].as(String)
  new_password = env.params.json["new_password"].as(String)

  user = Datastore.get_user(username)

  api_exception(user.nil?, ({"error": "User doesn't exists"}).to_json)
  user = user.not_nil!

  api_exception(
    user.id != env.user_id,
    ({"error": "Updating password of other users not allowed."}).to_json,
    403
  )

  api_exception(
    !Datastore.valid_user?(user.id, old_password),
    ({"error": "Invalid username or password"}).to_json,
    403
  )

  Datastore.set_user_password(user.id, new_password)
  user.to_json
end

# Delete a User
delete "/api/v1/users/:username" do |env|
  username = env.params.url["username"]

  user = Datastore.get_user(username)
  api_exception(user.nil?, ({"error": "User does not exists"}).to_json)
  user = user.not_nil!

  # Allow delete only if the logged in user is super admin
  # (Admin for all pools) or self user.
  api_exception(
    user.id != env.user_id && !Datastore.admin?(env.user_id),
    ({"error": "Forbidden to delete #{username}"}).to_json,
    403
  )

  Datastore.delete_user(user.id)
  env.response.status_code = 204
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
  forbidden_api_exception(!Datastore.admin?(env.user_id))

  Datastore.list_users.to_json
end

get "/api/v1/user-exists" do |env|
  if Datastore.zero_users?
    halt(env, status_code: 204, response: "{}")
  end

  "{}"
end

# Get User
get "/api/v1/users/:username" do |env|
  username = env.params.url["username"]
  forbidden_api_exception(!Datastore.admin?(env.user_id) && env.user_id != username)

  Datastore.get_user(username).to_json
end

# # Get User roles
# post "/api/v1/users/:username/roles" do |env|
#   username = env.params.url["username"]
#   if !Datastore.admin?(env.user_id) && env.user_id != username
#     halt(env, status_code: 403, response: ({"error": "Forbidden"}).to_json)
#   end

#   Datastore.list_roles(env.user_id).to_json
# end

# Get Pool users
get "/api/v1/pools/:pool_name/users" do |env|
  pool_name = env.params.url["pool_name"]
  forbidden_api_exception(!Datastore.admin?(env.user_id, pool_name))

  Datastore.list_users(pool_name).to_json
end

post "/api/v1/users/:username/api-keys" do |env|
  username = env.params.url["username"]
  password = env.params.json["password"].as(String)

  user = Datastore.get_user(username)
  api_exception(user.nil?, ({"error": "User doesn't exists"}).to_json)
  user = user.not_nil!

  api_exception(
    !Datastore.valid_user?(user.id, password),
    ({"error": "Invalid username or password"}).to_json,
    403
  )

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
