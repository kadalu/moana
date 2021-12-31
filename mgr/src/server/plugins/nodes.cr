require "./helpers"
require "../conf"
require "../datastore/*"

get "/api/v1/nodes" do |env|
  state = env.params.query["state"]

  nodes = Datastore.list_nodes_by_user(env.user_id)

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    "",
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.id].ok ? "Up" : "Down"
  end

  nodes.to_json
end

get "/api/v1/pools/:pool_name/nodes" do |env|
  pool_name = env.params.url["pool_name"]
  state = env.params.query["state"]

  next forbidden(env) unless Datastore.viewer?(env.user_id, pool_name)

  nodes = Datastore.list_nodes(pool_name)

  next nodes.to_json unless state

  resp = dispatch_action(
    ACTION_PING,
    pool_name,
    nodes
  )

  nodes.each do |node|
    node.state = resp.node_responses[node.id].ok ? "Up" : "Down"
  end

  nodes.to_json
end

get "/api/v1/pools/:pool_name/nodes/:node_name/services" do |env|
  pool_name = env.params.url["pool_name"]
  node_name = env.params.url["node_name"]

  # TODO: Handle Node authentication
  Datastore.list_services(pool_name, node_name).to_json
end

delete "/api/v1/pools/:pool_name/nodes/:node_name" do |env|
  pool_name = env.params.url["pool_name"]
  node_name = env.params.url["node_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "Pool doesn't exists"}.to_json))
  end

  node = Datastore.get_node(pool_name, node_name)
  if node.nil?
    halt(env, status_code: 400, response: ({"error": "Node doesn't exists"}.to_json))
  end

  if Datastore.storage_units_from_node?(pool.id, node.id)
    halt(env, status_code: 400, response: ({"error": "Node is part of one or more Volumes"}.to_json))
  end

  # TODO: Node action to remove Pool info from the node
  # so that the same node can join again to same pool or
  # another pool.

  Datastore.delete_node(pool.id, node.id)

  env.response.status_code = 204
end
