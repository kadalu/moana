require "./helpers"
require "../conf"
require "../datastore/*"

ACTION_NODE_INVITE_ACCEPT = "node_invite_accept"
ACTION_NODE_REMOVE        = "node_remove"

node_action ACTION_NODE_INVITE_ACCEPT do |data, _env|
  req = MoanaTypes::NodeRequest.from_json(data)

  data_file = Path.new(GlobalConfig.workdir, "info")
  if !File.exists?(data_file)
    next NodeResponse.new(false, {"error": "Node info file is not found in #{req.name}. Restart kadalu-mgr to regenerate the info file"}.to_json)
  end

  local_node_data = LocalNodeData.from_json(File.read(data_file))
  if local_node_data.pool_name != ""
    msg = local_node_data.pool_name == req.pool_name ? "the " : "a different "
    next NodeResponse.new(false, {"error": "Node is already part of #{msg} Pool"}.to_json)
  end

  # TODO: Change this to user check once user management is implemented
  if Datastore.pools_exists? && local_node_data.id != req.mgr_node_id
    next NodeResponse.new(false, {"error": "Node is already a Storage Manager for different Pools"}.to_json)
  end

  node = MoanaTypes::Node.new
  node.id = local_node_data.id
  node.token = UUID.random.to_s
  node.name = req.name

  local_node_data.pool_name = req.pool_name
  local_node_data.name = req.name
  local_node_data.token_hash = hash_sha256(node.token)
  local_node_data.mgr_token = req.mgr_token
  local_node_data.mgr_hostname = req.mgr_hostname
  local_node_data.mgr_port = req.mgr_port
  local_node_data.mgr_https = req.mgr_https

  # TODO: Handle error while writing node data
  File.write(data_file, local_node_data.to_json)

  # If this node is not a Manager
  # then set as agent.
  if !Datastore.manager?
    Datastore.set_agent
  end

  GlobalConfig.local_node = local_node_data
  NodeResponse.new(true, node.to_json)
end

node_action ACTION_NODE_REMOVE do |data, _env|
  req = MoanaTypes::NodeRequest.from_json(data)

  data_file = Path.new(GlobalConfig.workdir, "info")
  if !File.exists?(data_file)
    next NodeResponse.new(false, {"error": "Node info file is not found in #{req.name}. Restart kadalu-mgr to regenerate the info file"}.to_json)
  end

  local_node_data = LocalNodeData.from_json(File.read(data_file))
  if local_node_data.pool_name == ""
    next NodeResponse.new(true, "{}")
  elsif local_node_data.pool_name != req.pool_name
    next NodeResponse.new(false, {"error": "Node is already part of a different Pool"}.to_json)
  end

  # TODO: Change this to user check once user management is implemented
  if Datastore.pools_exists? && local_node_data.id != req.mgr_node_id
    next NodeResponse.new(false, {"error": "Node is already a Storage Manager for different Pools"}.to_json)
  end

  local_node_data.pool_name = ""
  local_node_data.name = req.name
  local_node_data.token_hash = ""
  if !Datastore.manager?
    local_node_data.mgr_hostname = ""
  end

  # TODO: Handle error while writing node data
  File.write(data_file, local_node_data.to_json)

  # Remove Agent identifier
  # Leave it as it is if it is Manager
  Datastore.remove_agent

  GlobalConfig.local_node = local_node_data
  NodeResponse.new(true, "")
end

def node_invite(pool_name : String, node_name : String, endpoint : String)
  invite = MoanaTypes::NodeRequest.new
  invite.endpoint = endpoint
  invite.pool_name = pool_name
  invite.name = node_name
  invite.mgr_node_id = GlobalConfig.local_node.id
  invite.mgr_port = Kemal.config.port
  invite.mgr_hostname = GlobalConfig.local_hostname
  # TODO: Set https based on config or Kemal config
  invite.mgr_https = false
  invite.mgr_token = UUID.random.to_s

  invite
end

def node_endpoint(node_name, endpoint = "")
  # TODO: Add detault http/https and port values from config
  # TODO: Add detault http/https and port values from config
  endpoint == "" ? "http://#{node_name}:3000" : endpoint
end

post "/api/v1/pools/:pool_name/nodes" do |env|
  pool_name = env.params.url["pool_name"]
  node_name = env.params.json["name"].as(String)

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  endpoint = node_endpoint(node_name, env.params.json.fetch("endpoint", "").as(String))

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  node = Datastore.get_node(pool_name, node_name)

  if !node.nil?
    halt(env, status_code: 400, response: ({"error": "Node is already part of the Pool"}.to_json))
  end

  invite = node_invite(pool_name, node_name, endpoint)

  participating_node = MoanaTypes::Node.new
  participating_node.endpoint = endpoint
  participating_node.name = node_name

  resp = dispatch_action(
    ACTION_NODE_INVITE_ACCEPT,
    pool_name,
    [participating_node],
    invite.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: resp.node_responses[node_name].response)
  end

  node = MoanaTypes::Node.from_json(resp.node_responses[node_name].response)
  Datastore.create_node(pool.id, node.id, node_name, endpoint, node.token, invite.mgr_token)

  # TODO: If Datastore.create_node fails then call Rollback

  # Do not expose node.token
  node.token = ""

  env.response.status_code = 201
  node.to_json
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

  invite = MoanaTypes::NodeRequest.new
  invite.endpoint = node.endpoint
  invite.pool_name = pool_name
  invite.name = node_name
  invite.mgr_node_id = GlobalConfig.local_node.id

  resp = dispatch_action(
    ACTION_NODE_REMOVE,
    pool_name,
    [node],
    invite.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: resp.node_responses[node.id].response)
  end

  Datastore.delete_node(pool.id, node.id)

  env.response.status_code = 204
end
