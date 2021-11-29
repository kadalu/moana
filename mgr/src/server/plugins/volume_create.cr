require "file_utils"

require "moana_types"
require "xattr"

require "../conf"
require "./helpers"
require "../services"
require "../datastore/*"
require "./ping"
require "../default_volfiles"

ACTION_VALIDATE_VOLUME_CREATE = "validate_volume_create"
ACTION_VOLUME_CREATE          = "volume_create"
ACTION_VOLUME_CREATE_STOPPED  = "volume_create_stopped"
VOLUME_ID_XATTR_NAME          = "trusted.glusterfs.volume-id"

node_action ACTION_VALIDATE_VOLUME_CREATE do |_|
  # req = MoanaTypes::Volume.from_json(data)
  # TODO: Validate all required things(xattr support,rootdir etc)
  NodeResponse.new(true, "")
end

alias VolumeRequestToNode = Tuple(Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, Array(MoanaTypes::Volfile)), MoanaTypes::Volume)

def volfile_get(name)
  # TODO: Add logic to read from the Templates directory
  case name
  when "client"
    CLIENT_VOLFILE
  when "storage_unit"
    STORAGE_UNIT_VOLFILE
  when "shd"
    SHD_VOLFILE
  else
    ""
  end
end

def participating_nodes(cluster_name, req)
  case req
  when MoanaTypes::Volume
    nodes = [] of String
    req.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        nodes << storage_unit.node_name
      end
    end
    nodes.uniq!
    Datastore.get_nodes(cluster_name, nodes)
  else
    [] of MoanaTypes::Node
  end
end

def handle_volume_create(data, stopped = false)
  services, volfiles, req = VolumeRequestToNode.from_json(data)

  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next unless storage_unit.node_name == GlobalConfig.local_node.name

      # Create the Storage Unit
      Dir.mkdir storage_unit.path

      test_xattr_name = "user.testattr"
      test_xattr_value = "testvalue"

      begin
        xattr = XAttr.new(storage_unit.path)
        xattr[test_xattr_name] = test_xattr_value
      rescue ex : IO::Error
        FileUtils.rmdir storage_unit.path
        return NodeResponse.new(false, {"error": "Extended attributes are not supported for #{storage_unit.node_name}:#{storage_unit.path} (Error: #{ex})"}.to_json)
      end

      # Set volume-id xattr, ignore if same Volume ID exists
      volume_id = UUID.new(req.id)
      begin
        xattr = XAttr.new(storage_unit.path, only_create: true)
        xattr[VOLUME_ID_XATTR_NAME] = volume_id.bytes.to_slice
      rescue ex : IO::Error
        if ex.os_error == Errno::EEXIST && xattr.not_nil![VOLUME_ID_XATTR_NAME] != volume_id.bytes.to_slice
          return NodeResponse.new(false, {"error": "Storage Unit #{storage_unit.node_name}:#{storage_unit.path} is already used with another Volume"}.to_json)
        else
          return NodeResponse.new(false, {"error": "Failed to set Volume ID Xattr. Error=#{ex}"}.to_json)
        end
      end

      # Create Meta directories
      Dir.mkdir_p "#{storage_unit.path}/.glusterfs/indices"
    end
  end

  unless volfiles[GlobalConfig.local_node.name]?.nil?
    Dir.mkdir_p(Path.new(GlobalConfig.workdir, "volfiles"))
    volfiles[GlobalConfig.local_node.name].each do |volfile|
      File.write(Path.new(GlobalConfig.workdir, "volfiles", "#{volfile.name}.vol"), volfile.content)
    end
  end

  unless services[GlobalConfig.local_node.name]?.nil?
    # TODO: Hard coded path change?
    Dir.mkdir_p("/var/log/kadalu")
    Dir.mkdir_p("/var/run/kadalu")
    services[GlobalConfig.local_node.name].each do |service|
      svc = Service.from_json(service.to_json)
      svc.start
    end
  end

  NodeResponse.new(true, "")
end

node_action ACTION_VOLUME_CREATE do |data|
  handle_volume_create(data, stopped: false)
end

node_action ACTION_VOLUME_CREATE_STOPPED do |data|
  handle_volume_create(data, stopped: true)
end

class NodeIsNotPartOfTheCluster < Exception
end

def node_details_add_to_volume(volume, nodes)
  nodes_lookup = Hash(String, MoanaTypes::Node).new

  nodes.each do |node|
    nodes_lookup[node.name] = node
  end

  volume.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.node = nodes_lookup[storage_unit.node_name]
    end
  end
end

def node_names(req)
  names = [] of String
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      names << storage_unit.node_name
    end
  end

  names
end

def node_errors(message, node_responses)
  errs = MoanaTypes::Error.new(message)

  node_responses.each do |node_name, resp|
    unless resp.ok
      errs.node_errors << MoanaTypes::NodeError.new(
        node_name,
        resp.status_code,
        MoanaTypes::Error.from_json(resp.response).error
      )
    end
  end

  errs
end

def port_used?(cluster_name, node_name, port)
  Datastore.port_active?(cluster_name, node_name, port) || Datastore.port_reserved?(cluster_name, node_name, port)
end

def services_and_volfiles(req)
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new
  volfiles = Hash(String, Array(MoanaTypes::Volfile)).new

  return {services, volfiles} if req.no_start

  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      # Generate Service Unit
      service = StorageUnitService.new(req.name, storage_unit)
      services[storage_unit.node_name] = [] of MoanaTypes::ServiceUnit unless services[storage_unit.node_name]?

      services[storage_unit.node_name] << service.unit

      # Generate Storage Unit Volfile
      # TODO: Expose option as req.storage_unit_volfile_template
      tmpl = volfile_get("storage_unit")
      content = Volfile.storage_unit_level("storage_unit", tmpl, req, storage_unit.id)
      volfiles[storage_unit.node_name] = [] of MoanaTypes::Volfile unless volfiles[storage_unit.node_name]?
      volfiles[storage_unit.node_name] << MoanaTypes::Volfile.new(service.id, content)

      if req.replicate_family?
        # Generate Self-Heal service file
        # Generate Self-Heal Volfile
      end
    end
  end

  {services, volfiles}
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
