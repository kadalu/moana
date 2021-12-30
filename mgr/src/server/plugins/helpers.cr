require "digest/sha256"

require "kemal"

require "../actions"

post "/_api/v1/:action" do |env|
  action = env.params.url["action"]
  begin
    req = env.params.json["data"].as(String)
    resp = Action.run(action, req)
    env.response.status_code = 400 if !resp.ok
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
  def user_id
    get("user_id").as(String)
  end
end
