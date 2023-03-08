require "./helpers"
require "../conf"
require "../datastore/*"

get "/api/v1/nodes" do |env|
  state = env.params.query["state"]
  forbidden_api_exception(!Datastore.viewer?(env.user_id))

  nodes = Datastore.list_nodes

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.name].ok ? "Up" : "Down"
  end

  nodes.to_json
end

get "/api/v1/nodes/:node_name/services" do |env|
  node_name = env.params.url["node_name"]

  forbidden_api_exception(env.get?("node_id").nil?)

  node = Datastore.get_node(node_name)
  api_exception(node.nil?, ({"error": "Node does not exist."}.to_json))
  node = node.not_nil!

  Datastore.list_services(node.name).to_json
end
