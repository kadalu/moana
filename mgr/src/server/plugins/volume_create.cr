require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

ACTION_VALIDATE_VOLUME_CREATE = "validate_volume_create"
ACTION_VOLUME_CREATE          = "volume_create"
ACTION_VOLUME_CREATE_STOPPED  = "volume_create_stopped"

node_action ACTION_VALIDATE_VOLUME_CREATE do |_|
  # req = MoanaTypes::Volume.from_json(data)
  # TODO: Validate all required things(xattr support,rootdir etc)
  NodeResponse.new(true, "")
end

alias VolumeRequestToNode = Tuple(Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, Array(MoanaTypes::Volfile)), MoanaTypes::Volume)

node_action ACTION_VOLUME_CREATE do |data|
  handle_volume_create(data, stopped: false)
end

node_action ACTION_VOLUME_CREATE_STOPPED do |data|
  handle_volume_create(data, stopped: true)
end

post "/api/v1/clusters/:cluster_name/volumes" do |env|
  cluster_name = env.params.url["cluster_name"]
  # TODO: Validate if env.request.body.nil?
  req = MoanaTypes::Volume.from_json(env.request.body.not_nil!)
  req.id = UUID.random.to_s if req.id == ""

  volume = Datastore.get_volume(cluster_name, req.name)

  unless volume.nil?
    halt(env, status_code: 400, response: ({"error": "Volume already exists"}.to_json))
  end

  # Validate if the nodes are part of the Cluster
  node_names(req).each do |node|
    unless Datastore.node_exists?(cluster_name, node)
      halt(env, status_code: 400, response: ({"error": "Node #{node} is not part of the Cluster"}.to_json))
    end
  end

  nodes = participating_nodes(cluster_name, req)
  node_details_add_to_volume(req, nodes)

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, cluster_name, nodes, "")
  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)
  end

  # If User specified the Port in the request then validate if
  # the port is already used.
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next if storage_unit.port == 0

      if port_used?(cluster_name, storage_unit.node_name, storage_unit.port)
        halt(env, status_code: 400, response: ({"error": "Port is already used(#{storage_unit.node_name}:#{storage_unit.port})"}).to_json)
      end
    end
  end

  # Local Validations
  resp = dispatch_action(
    ACTION_VALIDATE_VOLUME_CREATE,
    cluster_name,
    nodes,
    req.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Invalid Volume create request", resp.node_responses).to_json)
  end

  # Update Free Ports and reserve it
  # Also generate Brick ID
  # TODO: Update Brick type
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.id = UUID.random.to_s
      # Request doesn't contain the Port, find a free port
      if storage_unit.port == 0
        (49252..49452).each do |p|
          unless port_used?(cluster_name, storage_unit.node_name, p)
            storage_unit.port = p
            break
          end
        end
      end

      # No free port found
      if storage_unit.port == 0
        halt(env, status_code: 400, response: ({"error": "No free Port available in #{storage_unit.node_name}"}).to_json)
      end

      Datastore.reserve_port(cluster_name, storage_unit.node_name, storage_unit.port)
    end
  end

  # Generate Services and Volfiles if Volume to be started
  services, volfiles = services_and_volfiles(req)

  action = req.no_start ? ACTION_VOLUME_CREATE_STOPPED : ACTION_VOLUME_CREATE

  # Volume create action {req, services, volfiles}
  resp = dispatch_action(
    action,
    cluster_name,
    nodes,
    {services, volfiles, req}.to_json
  )

  if !resp.ok
    halt(env, status_code: 400, response: node_errors("Failed to create Volume", resp.node_responses).to_json)
  end

  # Save Services details
  services.each do |node, svcs|
    svcs.each do |svc|
      # Enable each Services
      Datastore.enable_service(cluster_name, node, svc)
    end
  end

  # Save Ports details
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      Datastore.activate_port(cluster_name, storage_unit.node_name, storage_unit.port)
    end
  end

  # Save Volume info
  Datastore.create_volume(cluster_name, req)

  env.response.status_code = 201
  req.to_json
end
