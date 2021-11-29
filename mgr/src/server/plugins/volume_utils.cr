require "file_utils"

require "moana_types"
require "xattr"

require "../conf"
require "../services"
require "../datastore/*"
require "../default_volfiles"

VOLUME_ID_XATTR_NAME = "trusted.glusterfs.volume-id"

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

TEST_XATTR_NAME  = "user.testattr"
TEST_XATTR_VALUE = "testvalue"

def validate_volume_create(req)
  # TODO: Validate Rootdir
  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next unless storage_unit.node_name == GlobalConfig.local_node.name

      unless File.exists?(Path[storage_unit.path].parent)
        return NodeResponse.new(false, {"error": "Storage unit parent directory(#{Path[storage_unit.path].parent}) not exists"}.to_json)
      end

      begin
        Dir.mkdir storage_unit.path
      rescue ex : Exception
        return NodeResponse.new(false, {"error": "Failed to create Storage unit path #{storage_unit.path} (Error: #{ex})"}.to_json)
      end

      begin
        xattr = XAttr.new(storage_unit.path)
        xattr[TEST_XATTR_NAME] = TEST_XATTR_VALUE
      rescue ex : IO::Error
        return NodeResponse.new(false, {"error": "Extended attributes are not supported for #{storage_unit.path} (Error: #{ex})"}.to_json)
      ensure
        FileUtils.rmdir storage_unit.path
      end
    end
  end

  NodeResponse.new(true, "")
end

def handle_volume_create(data, stopped = false)
  services, volfiles, req = VolumeRequestToNode.from_json(data)

  req.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      next unless storage_unit.node_name == GlobalConfig.local_node.name

      # Create the Storage Unit
      Dir.mkdir storage_unit.path

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
