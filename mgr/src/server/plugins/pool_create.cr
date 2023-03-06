require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./pool_utils.cr"

post "/api/v1/pools" do |env|
  forbidden_api_exception(!Datastore.maintainer?(env.user_id))

  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Pool.from_json(env.request.body.not_nil!)

  pool = Datastore.get_pool(req.name)
  api_exception(!pool.nil?, ({"error": "Pool already exists"}.to_json))

  req.id = req.pool_id == "" ? UUID.random.to_s : req.pool_id

  api_exception(
    req.pool_id != "" && !valid_uuid?(req.pool_id),
    ({"error": "Pool ID does not match UUID format"}.to_json)
  )

  # To avoid creating existing pool with pool-id option
  api_exception(
    req.pool_id != "" && Datastore.pool_exists_by_id?(req.id),
    ({"error": "Pool already exists with the given ID"}.to_json)
  )

  # TODO: Validate the request, dist count, storage_units count etc

  nodes = validate_and_add_nodes(req)
  node_details_add_to_pool(req, nodes)

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, nodes)
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  # If User specified the Port in the request then validate if
  # the port is already used.
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next if storage_unit.port == 0

      unless Datastore.port_available?(storage_unit.node.id, storage_unit.port)
        api_exception(true, ({"error": "Port is already used(#{storage_unit.node.name}:#{storage_unit.port})"}).to_json)
      end
    end
  end

  # Local Validations
  resp = dispatch_action(
    ACTION_VALIDATE_POOL_CREATE,
    nodes,
    req.to_json
  )

  api_exception(!resp.ok, node_errors("Invalid Pool create request", resp.node_responses).to_json)

  # Update Free Ports and reserve it
  # Also generate Brick ID
  # TODO: Update Brick type
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.id = UUID.random.to_s
      # Request doesn't contain the Port, find a free port
      if storage_unit.port == 0
        free_port = Datastore.free_port(storage_unit.node.id)
        storage_unit.port = free_port unless free_port.nil?
      end

      # No free port found
      api_exception(storage_unit.port == 0, ({"error": "No free Port available in #{storage_unit.node.name}"}).to_json)

      Datastore.reserve_port(storage_unit.node.id, storage_unit.port)
    end
  end

  # Generate Services and Volfiles if Pool to be started
  services, volfiles = services_and_volfiles(req)

  action = ACTION_POOL_CREATE
  req.state = "Started"
  if req.no_start
    action = ACTION_POOL_CREATE_STOPPED
    req.state = "Created"
  end

  # Pool create action {req, services, volfiles}
  resp = dispatch_action(
    action,
    nodes,
    {services, volfiles, req}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to create Pool", resp.node_responses).to_json)

  # Save Services details
  services.each do |node_id, svcs|
    svcs.each do |svc|
      # Enable each Services
      Datastore.enable_service(node_id, svc)
    end
  end

  storage_units = Hash(String, Hash(String, MoanaTypes::StorageUnit)).new
  resp.node_responses.each do |node, node_resp|
    storage_units[node] = Hash(String, MoanaTypes::StorageUnit).from_json(node_resp.response)
  end

  # Save Ports details and Update Storage unit metrics and FS type
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.metrics = storage_units[storage_unit.node.name][storage_unit.path].metrics
      storage_unit.fs = storage_units[storage_unit.node.name][storage_unit.path].fs
    end
  end

  set_pool_metrics(req)

  # Save Pool info
  Datastore.create_pool(req)

  env.response.status_code = 201
  req.to_json
end
