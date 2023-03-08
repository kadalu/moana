require "file_utils"

require "moana_types"
require "xattr"
require "volgen"

require "../conf"
require "../services"
require "../datastore/*"

TEST_XATTR_NAME  = "user.testattr"
TEST_XATTR_VALUE = "testvalue"

POOL_ID_XATTR_NAME = "trusted.glusterfs.volume-id"

alias PoolRequestToNode = Tuple(Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, Array(MoanaTypes::Volfile)), MoanaTypes::Pool)
alias PoolRequestToNodeWithAction = Tuple(Hash(String, Array(MoanaTypes::ServiceUnit)), Hash(String, Array(MoanaTypes::Volfile)), MoanaTypes::Pool, String)

ACTION_VALIDATE_POOL_CREATE = "validate_pool_create"
ACTION_POOL_CREATE          = "pool_create"
ACTION_POOL_CREATE_STOPPED  = "pool_create_stopped"
ACTION_MANAGE_SERVICES      = "manage_services"

node_action ACTION_VALIDATE_POOL_CREATE do |data, _env|
  req = MoanaTypes::Pool.from_json(data)
  validate_pool_create(req)
end

node_action ACTION_POOL_CREATE do |data, _env|
  handle_pool_create(data, stopped: false)
end

node_action ACTION_POOL_CREATE_STOPPED do |data, _env|
  handle_pool_create(data, stopped: true)
end

node_action ACTION_MANAGE_SERVICES do |data, _env|
  services, volfiles, rollback_pool, action = PoolRequestToNodeWithAction.from_json(data)
  save_volfiles(volfiles)
  sighup_processes(services)
  restart_shd_service_and_manage_rebalance_services(services, rollback_pool.name, action)
end

def volfile_get(name)
  # TODO: Add logic to read from the Templates directory
  case name
  when "client"
    File.read("/var/lib/kadalu/templates/client.vol.j2")
  when "storage_unit"
    File.read("/var/lib/kadalu/templates/storage_unit.vol.j2")
  when "shd"
    File.read("/var/lib/kadalu/templates/shd.vol.j2")
  else
    ""
  end
end

def participating_nodes(req)
  case req
  when MoanaTypes::Pool
    nodes = [] of MoanaTypes::Node
    req.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        nodes << storage_unit.node
      end
    end
    # Shorthand equivalant to
    # nodes.uniq! do |node|
    #   node.name
    # end
    nodes.uniq!(&.name)
    nodes
  when Array(MoanaTypes::Pool)
    nodes = [] of MoanaTypes::Node
    req.each do |pool|
      nodes += participating_nodes(pool)
    end

    nodes.uniq!(&.name)
    nodes
  else
    [] of MoanaTypes::Node
  end
end

def get_xattr(path, xattr_name)
  XAttr.get(path, xattr_name)
rescue ex : IO::Error
  # TODO: BSD systems raises ENOATTR
  return nil if ex.os_error == Errno::ENODATA
  raise ex
end

def validate_pool_create(req)
  # TODO: Validate Rootdir
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next unless storage_unit.node.name == GlobalConfig.local_node.name

      unless File.exists?(Path[storage_unit.path].parent)
        return NodeResponse.new(false, {"error": "Storage unit parent directory(#{Path[storage_unit.path].parent}) not exists"}.to_json)
      end

      storage_unit_pre_exists = File.exists?(storage_unit.path)

      begin
        Dir.mkdir_p storage_unit.path
      rescue ex : Exception
        return NodeResponse.new(false, {"error": "Failed to create Storage unit path #{storage_unit.path} (Error: #{ex})"}.to_json)
      end

      begin
        XAttr.set(storage_unit.path, TEST_XATTR_NAME, TEST_XATTR_VALUE)
        XAttr.remove(storage_unit.path, TEST_XATTR_NAME)
      rescue ex : IO::Error
        return NodeResponse.new(false, {"error": "Extended attributes are not supported for #{storage_unit.path} (Error: #{ex})"}.to_json)
      ensure
        FileUtils.rmdir storage_unit.path unless storage_unit_pre_exists
      end

      xattr_pool_id = get_xattr(storage_unit.path, POOL_ID_XATTR_NAME) if storage_unit_pre_exists

      # Storage unit already exists with volume-id xattr
      if storage_unit_pre_exists && !xattr_pool_id.nil?
        xattr_pool_id_string = UUID.new(xattr_pool_id.not_nil!.to_slice).to_s
        # --pool-id is not set
        if req.pool_id == ""
          return NodeResponse.new(false, {"error": "Storage unit #{storage_unit.path} is part of some other Pool or Stale"}.to_json)
          # Below req.id & req.pool_id are same
        elsif xattr_pool_id_string != req.id
          return NodeResponse.new(false, {"error": "Pool-id do not match to reuse storage-unit #{storage_unit.path}"}.to_json)
        end
      end
    end
  end

  NodeResponse.new(true, "")
end

def restart_shd_service_and_manage_rebalance_services(services, pool_name, action = "start")
  unless services[GlobalConfig.local_node.name]?.nil?
    services[GlobalConfig.local_node.name].each do |service|
      svc = Service.from_json(service.to_json)
      if svc.name == "shdservice"
        svc.restart(plugin: GlobalConfig.service_mgr)
      elsif svc.name == "fixlayoutservice" || svc.name == "migratedataservice"
        status_file_path = "/var/lib/kadalu/rebalance/#{pool_name}/#{svc.id}.json"
        FileUtils.rm(status_file_path) if File.exists?(status_file_path)
        if action == "start"
          svc.start(plugin: GlobalConfig.service_mgr)
        else
          svc.stop(plugin: GlobalConfig.service_mgr)
        end
      end
    end
  end

  NodeResponse.new(true, "")
end

def handle_node_pool_start_stop(data, action)
  services, volfiles, _ = PoolRequestToNode.from_json(data)

  if action == "start" && !volfiles[GlobalConfig.local_node.name]?.nil?
    Dir.mkdir_p(Path.new(GlobalConfig.workdir, "volfiles"))
    volfiles[GlobalConfig.local_node.name].each do |volfile|
      File.write(Path.new(GlobalConfig.workdir, "volfiles", "#{volfile.name}.vol"), volfile.content)
    end
  end

  unless services[GlobalConfig.local_node.name]?.nil?
    # TODO: Hard coded path change?
    Dir.mkdir_p("/var/log/kadalu")
    Dir.mkdir_p("/run/kadalu")
    services[GlobalConfig.local_node.name].each do |service|
      svc = Service.from_json(service.to_json)
      if action == "start"
        svc.start(plugin: GlobalConfig.service_mgr)
      else
        svc.stop(plugin: GlobalConfig.service_mgr)
      end
    end
  end

  NodeResponse.new(true, "")
end

def handle_pool_create(data, stopped = false)
  services, volfiles, req = PoolRequestToNode.from_json(data)
  resp = Hash(String, MoanaTypes::StorageUnit).new

  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next unless storage_unit.node.name == GlobalConfig.local_node.name

      # Create the Storage Unit
      Dir.mkdir_p storage_unit.path

      # Set volume-id xattr, ignore if same Volume ID exists
      pool_id = UUID.new(req.id)
      begin
        XAttr.set(storage_unit.path, POOL_ID_XATTR_NAME,
          pool_id.bytes.to_slice, only_create: true)
      rescue ex : IO::Error
        if ex.os_error != Errno::EEXIST
          return NodeResponse.new(false, {"error": "Failed to set Pool ID Xattr. Error=#{ex}"}.to_json)
        end
      end

      # Create Meta directories
      Dir.mkdir_p "#{storage_unit.path}/.glusterfs/indices"

      # Collect and Update FS type and Size
      rc, out, err = execute("df", ["-B1", "--output=fstype,used,avail,iused,iavail", storage_unit.path])
      if rc == 0
        # Example output
        #     Used      Avail IUsed  IFree
        # 41259008 1021997056     3 524285
        _, line = out.strip.split("\n")
        fstype, used, avail, iused, ifree = line.split
        storage_unit.fs = fstype
        storage_unit.metrics.size_used_bytes = used.to_i64
        storage_unit.metrics.size_free_bytes = avail.to_i64
        storage_unit.metrics.size_bytes = used.to_i64 + avail.to_i64
        storage_unit.metrics.inodes_used_count = iused.to_i64
        storage_unit.metrics.inodes_free_count = ifree.to_i64
        storage_unit.metrics.inodes_count = iused.to_i64 + ifree.to_i64
      else
        Log.error &.emit("Failed to collect Storage Unit Metrics", storage_unit: "#{storage_unit.path}", rc: "#{rc}", error: "#{err.strip}")
      end
      resp[storage_unit.path] = storage_unit
    end
  end

  save_volfiles(volfiles)

  unless services[GlobalConfig.local_node.name]?.nil?
    # TODO: Hard coded path change?
    Dir.mkdir_p("/var/log/kadalu")
    Dir.mkdir_p("/run/kadalu")
    services[GlobalConfig.local_node.name].each do |service|
      svc = Service.from_json(service.to_json)
      svc.start(plugin: GlobalConfig.service_mgr)
    end
  end

  NodeResponse.new(true, resp.to_json)
end

def node_details_add_to_pool(pool, nodes)
  nodes_lookup = Hash(String, MoanaTypes::Node).new

  nodes.each do |node|
    nodes_lookup[node.name] = node
  end

  pool.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit.node = nodes_lookup[storage_unit.node.name]
    end
  end
end

def node_names(req)
  names = [] of String
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      names << storage_unit.node.name
    end
  end

  names
end

def node_errors(message, node_responses)
  errs = MoanaTypes::Error.new(message)

  node_responses.each do |node_id, resp|
    unless resp.ok
      errs.node_errors << MoanaTypes::NodeError.new(
        node_id, # TODO: Add node name here
        resp.status_code,
        MoanaTypes::Error.from_json(resp.response).error
      )
    end
  end

  errs
end

def services_and_volfiles(req)
  services = Hash(String, Array(MoanaTypes::ServiceUnit)).new
  volfiles = Hash(String, Array(MoanaTypes::Volfile)).new

  return {services, volfiles} if req.no_start

  shd_services = Hash(String, Bool).new
  client_volfiles = Hash(String, Bool).new

  # Client Volfile
  tmpl = volfile_get("client")
  client_volfile_content = Volgen.generate(tmpl, req.to_json, req.options)

  # SHD Volfile
  shd_volfile_content = ""
  if req.replicate_family?
    tmpl = volfile_get("shd")
    shd_volfile_content = Volgen.generate(tmpl, req.to_json)
  end

  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      # Generate Service Unit
      service = StorageUnitService.new(req.name, storage_unit)
      services[storage_unit.node.name] = [] of MoanaTypes::ServiceUnit unless services[storage_unit.node.name]?

      services[storage_unit.node.name] << service.unit

      # Generate Storage Unit Volfile
      # TODO: Expose option as req.storage_unit_volfile_template
      tmpl = volfile_get("storage_unit")
      storage_unit.volume.id = req.id
      storage_unit.volume.name = req.name
      content = Volgen.generate(tmpl, storage_unit.to_json)
      volfiles[storage_unit.node.name] = [] of MoanaTypes::Volfile unless volfiles[storage_unit.node.name]?
      volfiles[storage_unit.node.name] << MoanaTypes::Volfile.new(service.id, content)

      # Store Client Volfile
      if client_volfiles[storage_unit.node.name]?.nil?
        volfiles[storage_unit.node.name] << MoanaTypes::Volfile.new(
          "#{req.name}", client_volfile_content
        )
        client_volfiles[storage_unit.node.name] = true
      end

      # Generate and add shd Volfiles and services only if it is
      # not added for that node.
      if req.replicate_family? && shd_services[storage_unit.node.name]?.nil?
        shd_services[storage_unit.node.name] = true
        service = ShdService.new(req.name, storage_unit.node.name)
        services[storage_unit.node.name] << service.unit
        volfiles[storage_unit.node.name] << MoanaTypes::Volfile.new(service.id, shd_volfile_content)
      end
    end
  end

  {services, volfiles}
end

def set_default_storage_unit_metrics(storage_unit)
  storage_unit.metrics.health = "Down"
end

def distribute_group_quorum(dist_grp)
  if dist_grp.replica_count > 0
    cnt = dist_grp.replica_count + dist_grp.arbiter_count
    (dist_grp.storage_units.size/cnt).ceil
  elsif dist_grp.disperse_count > 0
    dist_grp.disperse_count - dist_grp.redundancy_count
  else
    dist_grp.storage_units.size
  end
end

def distribute_group_health(dist_grp, up_storage_units_count)
  if up_storage_units_count == dist_grp.storage_units.size
    "Up"
  elsif up_storage_units_count >= distribute_group_quorum(dist_grp)
    "Partial"
  elsif up_storage_units_count > 0 && up_storage_units_count < distribute_group_quorum(dist_grp)
    "Degraded"
  else
    "Down"
  end
end

def pool_health(pool, up_dist_grps_count, down_dist_grps_count)
  if pool.distribute_groups.size == up_dist_grps_count
    "Up"
  elsif down_dist_grps_count > 0
    "Degraded"
  elsif up_dist_grps_count > 0
    "Partial"
  else
    "Down"
  end
end

def set_distribute_group_metrics(dist_grp)
  up_count = 0
  size_used_bytes : Int64 = 0
  size_free_bytes : Int64 = 0
  inodes_used_count : Int64 = 0
  inodes_free_count : Int64 = 0

  dist_grp.storage_units.each do |storage_unit|
    up_count += 1 if storage_unit.metrics.health == "Up"

    next if storage_unit.metrics.health == "Unknown"

    if dist_grp.replica_count > 0 || dist_grp.disperse_count > 0
      if size_used_bytes < storage_unit.metrics.size_used_bytes
        size_used_bytes = storage_unit.metrics.size_used_bytes
        size_free_bytes = storage_unit.metrics.size_free_bytes
        inodes_used_count = storage_unit.metrics.inodes_used_count
        inodes_free_count = storage_unit.metrics.inodes_free_count
      end
    else
      size_used_bytes += storage_unit.metrics.size_used_bytes
      size_free_bytes += storage_unit.metrics.size_free_bytes
      inodes_used_count += storage_unit.metrics.inodes_used_count
      inodes_free_count += storage_unit.metrics.inodes_free_count
    end
  end

  if dist_grp.disperse_count > 0
    # TODO: Calculate for disperse based on data and redundancy count
    data_count = (dist_grp.disperse_count - dist_grp.redundancy_count)
    size_used_bytes = size_used_bytes * data_count
    size_free_bytes = size_free_bytes * data_count
    inodes_used_count = inodes_used_count * data_count
    inodes_free_count = inodes_free_count * data_count
  end

  dist_grp.metrics.health = distribute_group_health(dist_grp, up_count)
  dist_grp.metrics.size_used_bytes = size_used_bytes
  dist_grp.metrics.size_free_bytes = size_free_bytes
  dist_grp.metrics.size_bytes = size_used_bytes + size_free_bytes
  dist_grp.metrics.inodes_used_count = inodes_used_count
  dist_grp.metrics.inodes_free_count = inodes_free_count
  dist_grp.metrics.inodes_count = inodes_used_count + inodes_free_count
end

def set_pool_metrics(pool)
  up_count : Int32 = 0
  down_count : Int32 = 0
  size_used_bytes : Int64 = 0
  size_free_bytes : Int64 = 0
  inodes_used_count : Int64 = 0
  inodes_free_count : Int64 = 0

  pool.distribute_groups.each do |dist_grp|
    next if dist_grp.metrics.health == "Unknown"

    set_distribute_group_metrics(dist_grp)
    up_count += 1 if dist_grp.metrics.health == "Up"
    down_count += 1 if dist_grp.metrics.health == "Down"

    size_used_bytes += dist_grp.metrics.size_used_bytes
    size_free_bytes += dist_grp.metrics.size_free_bytes
    inodes_used_count += dist_grp.metrics.inodes_used_count
    inodes_free_count += dist_grp.metrics.inodes_free_count
  end

  pool.metrics.health = pool_health(pool, up_count, down_count)
  pool.metrics.size_used_bytes = size_used_bytes
  pool.metrics.size_free_bytes = size_free_bytes
  pool.metrics.size_bytes = size_used_bytes + size_free_bytes
  pool.metrics.inodes_used_count = inodes_used_count
  pool.metrics.inodes_free_count = inodes_free_count
  pool.metrics.inodes_count = inodes_used_count + inodes_free_count
end

def save_volfiles(volfiles)
  unless volfiles[GlobalConfig.local_node.name]?.nil?
    Dir.mkdir_p(Path.new(GlobalConfig.workdir, "volfiles"))
    volfiles[GlobalConfig.local_node.name].each do |volfile|
      File.write(Path.new(GlobalConfig.workdir, "volfiles", "#{volfile.name}.vol"), volfile.content)
    end
  end
end

def sighup_processes(services)
  # Send SIGHUP to all the processes (Storage Unit and SHD processes)
  unless services[GlobalConfig.local_node.name]?.nil?
    services[GlobalConfig.local_node.name].each do |service|
      svc = Service.from_json(service.to_json)
      svc.signal(Signal::HUP) if svc.running?
    end
  end
end

def combine_req_and_pool(req, pool)
  rollback_pool = MoanaTypes::Pool.new

  rollback_pool.id = pool.id
  rollback_pool.name = pool.name
  rollback_pool.state = pool.state

  combined_pool_options = pool.options.merge(req.options).compact
  rollback_pool.options = combined_pool_options

  rollback_pool.distribute_groups.concat(pool.distribute_groups)
  rollback_pool.distribute_groups.concat(req.distribute_groups)

  rollback_pool
end

# Validate if the nodes are part of the Pool
# Also fetch the full node details
def validate_and_add_nodes(req)
  nodes = [] of MoanaTypes::Node

  participating_nodes(req).each do |n|
    node = Datastore.get_node(n.name)
    if node.nil?
      if req.auto_add_nodes
        endpoint = node_endpoint(n.name)
        invite = node_invite(n.name, endpoint)

        participating_node = MoanaTypes::Node.new
        participating_node.endpoint = endpoint
        participating_node.name = n.name

        resp = dispatch_action(
          ACTION_NODE_INVITE_ACCEPT,
          [participating_node],
          invite.to_json
        )

        api_exception(!resp.ok, ({"error": resp.node_responses[n.name].response}.to_json))

        node = MoanaTypes::Node.from_json(resp.node_responses[n.name].response)
        node.endpoint = endpoint
        Datastore.create_node(node.id, n.name, endpoint, node.token, invite.mgr_token)
      end

      api_exception(node.nil?, ({"error": "Node #{n.name} is not part of the Cluster"}.to_json))
    end

    nodes << node unless node.nil?
  end

  nodes
end

def add_fix_layout_service(services, pool_name, node, storage_unit)
  service = FixLayoutService.new(pool_name, storage_unit)
  services[node.name] = [] of MoanaTypes::ServiceUnit unless services[node.name]?
  services[node.name] << service.unit

  services
end

def add_migrate_data_service(services, pool_name, node, storage_unit)
  service = MigrateDataService.new(pool_name, storage_unit)
  services[node.name] = [] of MoanaTypes::ServiceUnit unless services[node.name]?
  services[node.name] << service.unit

  services
end
