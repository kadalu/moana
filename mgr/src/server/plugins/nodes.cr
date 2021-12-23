require "./helpers"
require "../conf"
require "../datastore/*"

get "/api/v1/nodes" do |env|
  state = env.params.query["state"]

  nodes = Datastore.list_nodes

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    "",
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.name].ok ? "Up" : "Down"
  end

  nodes.to_json
end

get "/api/v1/pools/:pool_name/nodes" do |env|
  pool_name = env.params.url["pool_name"]
  state = env.params.query["state"]

  nodes = Datastore.list_nodes(pool_name)

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    pool_name,
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.name].ok ? "Up" : "Down"
  end

  nodes.to_json
end

get "/api/v1/pools/:pool_name/nodes/:node_name/services" do |env|
  pool_name = env.params.url["pool_name"]
  node_name = env.params.url["node_name"]

  Datastore.list_services(pool_name, node_name).to_json
end
