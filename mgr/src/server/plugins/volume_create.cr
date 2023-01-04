require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

post "/api/v1/pools/:pool_name/volumes" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Volume.from_json(env.request.body.not_nil!)

  volume = Datastore.get_volume(pool_name, req.name)
  api_exception(!volume.nil?, ({"error": "Volume already exists"}.to_json))

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    api_exception(!req.auto_create_pool, ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))

    # If the user is not global maintainer, can't create a Pool
    forbidden_api_exception(!Datastore.maintainer?(env.user_id))

    pool = create_pool(pool_name)
  end

  req.id = req.volume_id == "" ? UUID.random.to_s : req.volume_id

  api_exception(
    req.volume_id != "" && !valid_uuid?(req.volume_id),
    ({"error": "Volume ID does not match UUID format"}.to_json)
  )

  # To avoid creating existing volume with volume-id option
  api_exception(
    req.volume_id != "" && Datastore.volume_exists_by_id?(pool.not_nil!.id, req.id),
    ({"error": "Volume already exists with the given ID"}.to_json)
  )

  # TODO: Validate the request, dist count, storage_units count etc

  nodes = validate_and_add_nodes(pool.not_nil!, req)
  node_details_add_to_volume(req, nodes)

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, pool_name, nodes, "")
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  # If User specified the Port in the request then validate if
  # the port is already used.
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next if storage_unit.port == 0

      unless Datastore.port_available?(pool.not_nil!.id, storage_unit.node.id, storage_unit.port)
        api_exception(true, ({"error": "Port is already used(#{storage_unit.node.name}:#{storage_unit.port})"}).to_json)
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

  api_exception(!resp.ok, node_errors("Invalid Volume create request", resp.node_responses).to_json)

  # Update Free Ports and reserve it
  # Also generate Brick ID
  # TODO: Update Brick type
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.id = UUID.random.to_s
      # Request doesn't contain the Port, find a free port
      if storage_unit.port == 0
        free_port = Datastore.free_port(pool.not_nil!.id, storage_unit.node.id)
        storage_unit.port = free_port unless free_port.nil?
      end

      # No free port found
      api_exception(storage_unit.port == 0, ({"error": "No free Port available in #{storage_unit.node.name}"}).to_json)

      Datastore.reserve_port(pool.not_nil!.id, storage_unit.node.id, storage_unit.port)
    end
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

  api_exception(!resp.ok, node_errors("Failed to create Volume", resp.node_responses).to_json)

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
