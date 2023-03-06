require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./pool_utils.cr"

put "/api/v1/pools" do |env|
  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Pool.from_json(env.request.body.not_nil!)
  forbidden_api_exception(!Datastore.maintainer?(env.user_id, req.name))

  pool = Datastore.get_pool(req.name)
  api_exception(pool.nil?, ({"error": "The Pool (#{req.name}) doesn't exists"}.to_json))

  pool = pool.not_nil!

  req.id = pool.id

  # Checks for types & storage unit coun mismatch
  api_exception(pool.type != req.type, ({"error": "Pool type mismatch"}.to_json))

  api_exception(
    (pool.not_nil!.distribute_groups.size % req.distribute_groups.size) != 0,
    ({"error": "Distribute group mismatch"}.to_json)
  )

  req.distribute_groups.each do |dist_grp_req|
    pool.distribute_groups.each do |dist_grp_vol|
      api_exception(
        dist_grp_req.replica_count != dist_grp_vol.replica_count,
        ({"error": "Replica count mismatch"}.to_json)
      )

      api_exception(
        dist_grp_req.disperse_count != dist_grp_vol.disperse_count,
        ({"error": "Disperse count mismatch"}.to_json)
      )

      api_exception(
        dist_grp_req.redundancy_count != dist_grp_vol.redundancy_count,
        ({"error": "Redundancy count mismatch"}.to_json)
      )
    end
  end

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

      api_exception(
        !Datastore.port_available?(storage_unit.node.id, storage_unit.port),
        ({"error": "Port is already used(#{storage_unit.node.name}:#{storage_unit.port})"}).to_json
      )
    end
  end

  # Local Validations
  resp = dispatch_action(
    ACTION_VALIDATE_POOL_CREATE,
    nodes,
    req.to_json
  )

  api_exception(!resp.ok, node_errors("Invalid Pool expand request", resp.node_responses).to_json)

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

  # Updating the DB before confirming of completion of all checks during,
  # pool expansion might be troublesome to delete data from DB if the action fails.
  # So combine existing & new vol_data required by volfile, services generation & pool create only.
  rollback_pool = combine_req_and_pool(req, pool)

  # Generate Services and Volfiles if Pool to be started
  services, volfiles = services_and_volfiles(rollback_pool)

  action = ACTION_POOL_CREATE
  req.state = pool.state
  if pool.state != "Started"
    action = ACTION_POOL_CREATE_STOPPED
  end

  resp = dispatch_action(
    action,
    nodes,
    {services, volfiles, req}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to expand Pool", resp.node_responses).to_json)

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

  existing_nodes = participating_nodes(pool)

  # Add only the first existing node for fix-layout service
  services = add_fix_layout_service(services, req.name, existing_nodes[0],
    pool.distribute_groups[0].storage_units[0])

  # Remove duplicated node objects to avoid multiple node_actions to same node.
  all_unique_nodes = (existing_nodes + nodes).uniq(&.id)

  # Below node action is to be run in all nodes of expanded pool.
  # After expansion of pool, volfiles will be changed with newer storage_units,
  # Send new volfiles to save in all nodes & notify the glusterfsd process about,
  # reloaded volfiles through sighup. Finally restart SHD process if exists &
  # Run fix-layout service in the first node only.
  resp = dispatch_action(
    ACTION_MANAGE_SERVICES,
    all_unique_nodes,
    {services, volfiles, rollback_pool, "start"}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to restart SHD/start fix-layout service", resp.node_responses).to_json)

  # Save Pool info
  Datastore.update_pool(req, pool.distribute_groups.size)

  # Save Services details. If service already exist, update with newer details
  services.each do |node_id, svcs|
    svcs.each do |svc|
      begin
        Datastore.enable_service(node_id, svc)
      rescue ex : Exception
        Datastore.update_service(node_id, svc)
      end
    end
  end

  env.response.status_code = 200

  updated_pool = Datastore.get_pool(req.name)
  updated_pool.to_json
end
