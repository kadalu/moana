require "digest/sha256"

require "kemal"

require "../actions"

def handle_node_action(env)
  action = env.params.url["action"]
  req = env.params.json["data"].as(String)

  # Skip authorization for new node additions
  if action != ACTION_NODE_INVITE_ACCEPT
    auth = env.request.headers["Authorization"]?

    if auth.nil?
      return NodeResponse.new(false, {"error": "Authorization header is not set"}.to_json, 401)
    end

    bearer, _, token = auth.partition(" ")
    if bearer.downcase != "bearer" || token == ""
      return NodeResponse.new(false, {"error": "Invalid Authoriation header"}.to_json, 401)
    end

    token_hash = hash_sha256(token)
    if token_hash != GlobalConfig.local_node.token_hash
      return NodeResponse.new(false, {"error": "Invalid node token"}.to_json, 401)
    end
  end

  resp = Action.run(action, req, env)
  resp.status_code = 400 unless resp.ok

  resp
rescue ex : Exception
  Log.error exception: ex, &.emit("#{action} Failed", error: "#{ex}")
  NodeResponse.new(false, {"error": "#{action} Failed"}.to_json, 500)
end

post "/_api/v1/:action" do |env|
  resp = handle_node_action(env)
  # Do not change the response status code
  # Kemal framework will raise exception or adds new error
  # response if the status code is not 200.
  # Response status is decided by the caller based
  # on resp.status_code and resp.ok
  env.response.status_code = 200
  resp.to_json
end

def node_action(name, &block : String, HTTP::Server::Context -> NodeResponse)
  Action.add(name, &block)
end

def dispatch_action(name, pool_name, nodes, data)
  Action.dispatch(name, pool_name, nodes, data)
end

def dispatch_action(name, pool_name, nodes)
  Action.dispatch(name, pool_name, nodes, "")
end

def hash_sha256(value : String)
  Digest::SHA256.digest(value).hexstring
end

def execute(cmd, args)
  stdout = IO::Memory.new
  stderr = IO::Memory.new
  status = Process.run(cmd, args: args, output: stdout, error: stderr)
  if status.success?
    {status.exit_code, stdout.to_s, ""}
  else
    {status.exit_code, "", stderr.to_s}
  end
end

class HTTP::Server::Context
  # Reopen the Server Context and add a shortcut
  # to access user_id set in Server Context
  def user_id
    get("user_id").as(String)
  end
end

def forbidden(env)
  env.response.status_code = 403
  env.response.content_type = "application/json"
  env.response.print ({"error": "Forbidden. Insufficient permissions"}).to_json
end

def valid_uuid?(val)
  UUID.new(val)
  true
rescue ArgumentError
  false
end
