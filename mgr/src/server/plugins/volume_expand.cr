require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

ACTION_RESTART_SHD_SERVICE_AND_SIGHUP_PROCESSES = "restart_shd_service_and_sighup_processes"

node_action ACTION_RESTART_SHD_SERVICE_AND_SIGHUP_PROCESSES do |data, _env|
  services, volfiles, _ = VolumeRequestToNode.from_json(data)
  save_volfiles(volfiles)
  sighup_processes(services)
  restart_shd_service(services)
end

put "/api/v1/pools/:pool_name/volumes" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Volume.from_json(env.request.body.not_nil!)

  volume = Datastore.get_volume(pool_name, req.name)
  api_exception(volume.nil?, ({"error": "The Volume (#{req.name}) doesn't exists"}.to_json))

  volume = volume.not_nil!
  pool = volume.pool

  req.id = volume.not_nil!.id

  # Checks for types & storage unit coun mismatch
  api_exception(volume.not_nil!.type != req.type, ({"error": "Volume type mismatch"}.to_json))

  api_exception(
    (volume.not_nil!.distribute_groups.size % req.distribute_groups.size) != 0,
    ({"error": "Distribute group mismatch"}.to_json)
  )

  req.distribute_groups.each do |dist_grp_req|
    volume.not_nil!.distribute_groups.each do |dist_grp_vol|
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

      api_exception(
        !Datastore.port_available?(pool.not_nil!.id, storage_unit.node.id, storage_unit.port),
        ({"error": "Port is already used(#{storage_unit.node.name}:#{storage_unit.port})"}).to_json
      )
    end
  end

  # Local Validations
  resp = dispatch_action(
    ACTION_VALIDATE_VOLUME_CREATE,
    pool_name,
    nodes,
    req.to_json
  )

  api_exception(!resp.ok, node_errors("Invalid Volume expand request", resp.node_responses).to_json)

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

  # Updating the DB before confirming of completion of all checks during,
  # volume expansion might be troublesome to delete data from DB if the action fails.
  # So combine existing & new vol_data required by volfile, services generation & volume create only.
  rollback_volume = combine_req_and_volume(req, volume.not_nil!)

  # Generate Services and Volfiles if Volume to be started
  services, volfiles = services_and_volfiles(rollback_volume)

  action = ACTION_VOLUME_CREATE
  req.state = volume.state
  if volume.state != "Started"
    action = ACTION_VOLUME_CREATE_STOPPED
  end

  resp = dispatch_action(
    action,
    pool_name,
    nodes,
    {services, volfiles, req}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to expand Volume", resp.node_responses).to_json)

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

  existing_nodes = participating_nodes(pool_name, volume)

  # Remove duplicated node objects to avoid multiple node_actions to same node.
  all_unique_nodes = (existing_nodes + nodes).uniq(&.id)

  # Below node action is to be run in all nodes of expanded volume.
  # After expansion of volume, volfiles will be changed with newer storage_units,
  # Send new volfiles to save in all nodes & notify the glusterfsd process about,
  # reloaded volfiles through sighup. Finally restart SHD process if exists.
  resp = dispatch_action(
    ACTION_RESTART_SHD_SERVICE_AND_SIGHUP_PROCESSES,
    pool_name,
    all_unique_nodes,
    {services, volfiles, rollback_volume}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to restart SHD service", resp.node_responses).to_json)

  # Save Volume info
  Datastore.update_volume(pool.not_nil!.id, req, volume.not_nil!.distribute_groups.size)

  # Save Services details. If service already exist, update with newer details
  services.each do |node_id, svcs|
    svcs.each do |svc|
      begin
        Datastore.enable_service(pool.not_nil!.id, node_id, svc)
      rescue ex : Exception
        Datastore.update_service(pool.not_nil!.id, node_id, svc)
      end
    end
  end

  env.response.status_code = 200

  updated_volume = Datastore.get_volume(pool_name, req.name)
  updated_volume.to_json
end
