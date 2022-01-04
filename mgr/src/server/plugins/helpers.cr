require "digest/sha256"

require "kemal"

require "../actions"

post "/_api/v1/:action" do |env|
  action = env.params.url["action"]
  begin
    req = env.params.json["data"].as(String)
    resp = Action.run(action, req)
    env.response.status_code = 400 if !resp.ok
    puts "HELLO"
    STDERR.puts "HELLO STDERR"
    auth = env.request.headers["Authorization"]?

    if action != ACTION_NODE_INVITE_ACCEPT
        if auth.nil?
            halt(env, status_code: 401, response: ({"error": "Authorization header is not set"}).to_json)
        end

        bearer, _, token = auth.partition(" ")
        if bearer.downcase != "bearer" || token == ""
            halt(env, status_code: 401, response: ({"error": "Invalid Authoriation header"}).to_json)
        end

        token_hash = hash_sha256(token)
        if token_hash != GlobalConfig.local_node.token_hash
            halt(env, status_code: 403, response: ({"error": "Invalid node token"}).to_json)
        end
    end

  rescue ex : Exception
    Log.error &.emit("#{action} Failed", error: "#{ex}")
    env.response.status_code = 500
    resp = NodeResponse.new(false, ({"error": "#{action} Failed"}).to_json)
  end

  resp.status_code = env.response.status_code
  resp.to_json
end

def node_action(name, &block : String -> NodeResponse)
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
