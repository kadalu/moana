require "./helpers"
require "../datastore/*"

ACTION_NODE_UPTIME = "node_uptime"

node_action ACTION_NODE_UPTIME do |_|
  rc, out, err = execute("uptime", ["--pretty"])

  if rc == 0
    NodeResponse.new(true, {out.strip}.to_json)
  else
    NodeResponse.new(false, {"error": err}.to_json)
  end
end

get "/api/v1/pools/:pool_name/uptime" do |env|
  pool_name = env.params.url["pool_name"]

  nodes = Datastore.list_nodes(pool_name)

  resp = dispatch_action(
    ACTION_NODE_UPTIME,
    pool_name,
    nodes
  )

  nodes.each do |node|
    if resp.node_responses[node.name].ok
      node.uptime = Tuple(String).from_json(resp.node_responses[node.name].response)[0]
    end
  end

  nodes.to_json
end
