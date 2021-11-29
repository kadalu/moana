require "./helpers"
require "../conf"
require "../datastore/*"

get "/api/v1/clusters/:cluster_name/nodes" do |env|
  cluster_name = env.params.url["cluster_name"]
  state = env.params.query["state"]

  nodes = Datastore.list_nodes(cluster_name)

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    cluster_name,
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.name].ok ? "Up" : "Down"
  end

  nodes.to_json
end
