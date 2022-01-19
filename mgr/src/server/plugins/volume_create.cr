require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

ACTION_VALIDATE_VOLUME_CREATE = "validate_volume_create"
ACTION_VOLUME_CREATE          = "volume_create"
ACTION_VOLUME_CREATE_STOPPED  = "volume_create_stopped"

node_action ACTION_VALIDATE_VOLUME_CREATE do |data|
  req = MoanaTypes::Volume.from_json(data)
  validate_volume_create(req)
end

node_action ACTION_VOLUME_CREATE do |data|
  handle_volume_create(data, stopped: false)
end

node_action ACTION_VOLUME_CREATE_STOPPED do |data|
  handle_volume_create(data, stopped: true)
end

post "/api/v1/pools/:pool_name/volumes" do |env|
  pool_name = env.params.url["pool_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Volume.from_json(env.request.body.not_nil!)

  volume = Datastore.get_volume(pool_name, req.name)
  unless volume.nil?
    halt(env, status_code: 400, response: ({"error": "Volume already exists"}.to_json))
  end

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    unless req.auto_create_pool
      halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
    end

    # If the user is not global maintainer, can't create a Pool
    unless Datastore.maintainer?(env.user_id)
      halt(env, status_code: 403, response: ({"error": "Forbidden"}.to_json))
    end

    pool = create_pool(pool_name)
  end

  req.id = req.volume_id == "" ? UUID.random.to_s : req.volume_id

  if req.volume_id != "" && !valid_uuid?(req.volume_id)
    halt(env, status_code: 400, response: ({"error": "Volume ID does not match UUID format"}.to_json))
  end

  # To avoid creating existing volume with volume-id option
  if req.volume_id != "" && Datastore.volume_exists_by_id?(pool.not_nil!.id, req.id)
    halt(env, status_code: 400, response: ({"error": "Volume already exists with the given ID"}.to_json))
  end

  # TODO: Validate the request, dist count, storage_units count etc

  nodes = [] of MoanaTypes::Node

  # Validate if the nodes are part of the Pool
  # Also fetch the full node details
  invalid_node = false
  invalid_node_name = ""
  invalid_reason = ""
  participating_nodes(pool_name, req).each do |n|
    node = Datastore.get_node(pool_name, n.name)
    if node.nil?
      if req.auto_add_nodes
        endpoint = node_endpoint(n.name)
        invite = node_invite(pool_name, n.name, endpoint)

        participating_node = MoanaTypes::Node.new
        participating_node.endpoint = endpoint
        participating_node.name = n.name

        resp = dispatch_action(
          ACTION_NODE_INVITE_ACCEPT,
          pool_name,
          [participating_node],
          invite.to_json
        )

        if !resp.ok
          invalid_reason = resp.node_responses[n.name].response
          invalid_node = true
          invalid_node_name = n.name
          break
        end

        node = MoanaTypes::Node.from_json(resp.node_responses[n.name].response)
        node.endpoint = endpoint
        Datastore.create_node(pool.not_nil!.id, node.id, n.name, endpoint, node.token)
      end

      if node.nil?
        invalid_node = true
        invalid_node_name = n.name
        break
      end
    end

    nodes << node
  end

  if invalid_node
    invalid_reason = invalid_reason == "" ? "Node #{invalid_node_name} is not part of the Pool" : invalid_reason
    halt(env, status_code: 400, response: ({"error": invalid_reason}.to_json))
  end

  node_details_add_to_volume(req, nodes)

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, pool_name, nodes, "")
  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)
  end

  # If User specified the Port in the request then validate if
  # the port is already used.
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next if storage_unit.port == 0

      unless Datastore.port_available?(pool.not_nil!.id, storage_unit.node.id, storage_unit.port)
        # TODO: Move this halt out of the loop
        halt(env, status_code: 400, response: ({"error": "Port is already used(#{storage_unit.node.name}:#{storage_unit.port})"}).to_json)
      end
    end
  end

  # Local Validations
  resp = dispatch_action(
    ACTION_VALIDATE_VOLUME_CREATE,
    pool_name,
    nodes,
    req.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Invalid Volume create request", resp.node_responses).to_json)
  end

  # Update Free Ports and reserve it
  # Also generate Brick ID
  # TODO: Update Brick type
  no_port_available = false
  no_port_storage_node = ""
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.id = UUID.random.to_s
      # Request doesn't contain the Port, find a free port
      if storage_unit.port == 0
        free_port = Datastore.free_port(pool.not_nil!.id, storage_unit.node.id)
        storage_unit.port = free_port unless free_port.nil?
      end

      # No free port found
      if storage_unit.port == 0
        # Using halt directly from here will not work. Since it adds `next`
        # and it just breaks the Storage_unit loop
        no_port_available = true
        no_port_storage_node = storage_unit.node.name
        break
      end

      Datastore.reserve_port(pool.not_nil!.id, storage_unit.node.id, storage_unit.port)
    end

    break if no_port_available
  end

  if no_port_available
    halt(env, status_code: 400, response: ({"error": "No free Port available in #{no_port_storage_node}"}).to_json)
  end

  # Generate Services and Volfiles if Volume to be started
  services, volfiles = services_and_volfiles(req)

  action = ACTION_VOLUME_CREATE
  req.state = "Started"
  if req.no_start
    action = ACTION_VOLUME_CREATE_STOPPED
    req.state = "Created"
  end

  # Volume create action {req, services, volfiles}
  resp = dispatch_action(
    action,
    pool_name,
    nodes,
    {services, volfiles, req}.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Failed to create Volume", resp.node_responses).to_json)
  end

  # Save Services details
  services.each do |node_id, svcs|
    svcs.each do |svc|
      # Enable each Services
      Datastore.enable_service(pool.not_nil!.id, node_id, svc)
    end
  end

  storage_units = Hash(String, Hash(String, MoanaTypes::StorageUnit)).new
  resp.node_responses.each do |node, node_resp|
    storage_units[node] = Hash(String, MoanaTypes::StorageUnit).from_json(node_resp.response)
  end

  # Save Ports details and Update Storage unit metrics and FS type
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.metrics = storage_units[storage_unit.node.id][storage_unit.path].metrics
      storage_unit.fs = storage_units[storage_unit.node.id][storage_unit.path].fs
    end
  end

  set_volume_metrics(req)

  # Save Volume info
  Datastore.create_volume(pool.not_nil!.id, req)

  env.response.status_code = 201
  req.to_json
end
