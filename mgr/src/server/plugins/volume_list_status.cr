require "./helpers"
require "../datastore/*"
require "./volume_utils"

ACTION_VOLUME_STATUS = "volume_status"

class VolumeNotFound < Exception
end

struct VolumeStatusRequestToNode
  include JSON::Serializable

  property service_units = [] of MoanaTypes::ServiceUnit, storage_units = [] of MoanaTypes::StorageUnit

  def initialize
  end
end

node_action ACTION_VOLUME_STATUS do |data, _env|
  Log.debug &.emit("Node Action", action: ACTION_VOLUME_STATUS, data: data)

  req = Hash(String, VolumeStatusRequestToNode).from_json(data)
  resp = VolumeStatusRequestToNode.new
  req.each do |node_name, node_data|
    next unless node_name == GlobalConfig.local_node.name

    # Fetch Services Status
    node_data.service_units.each do |service|
      svc = Service.from_json(service.to_json)
      service.metrics.health = svc.running? ? "Up" : "Down"
      # TODO: Collect CPU, Memory and Uptime details
      resp.service_units << service
    end

    node_data.storage_units.each do |storage_unit|
      svc = Service.from_json(storage_unit.service.to_json)
      storage_unit.metrics.health = svc.running? ? "Up" : "Down"
      # TODO: Collect CPU, Memory and Uptime details

      rc, out, err = execute("df", ["-B1", "--output=used,avail,iused,iavail", storage_unit.path])
      unless rc == 0
        Log.error &.emit("Failed to collect Storage Unit Metrics", storage_unit: "#{storage_unit.path}", rc: "#{rc}", error: "#{err.strip}")
        next
      end

      # Example output
      #     Used      Avail IUsed  IFree
      # 41259008 1021997056     3 524285
      _, line = out.strip.split("\n")
      used, avail, iused, ifree = line.split
      storage_unit.metrics.size_used_bytes = used.to_i64
      storage_unit.metrics.size_free_bytes = avail.to_i64
      storage_unit.metrics.size_bytes = used.to_i64 + avail.to_i64
      storage_unit.metrics.inodes_used_count = iused.to_i64
      storage_unit.metrics.inodes_free_count = ifree.to_i64
      storage_unit.metrics.inodes_count = iused.to_i64 + ifree.to_i64
      resp.storage_units << storage_unit
    end
  end

  NodeResponse.new(true, resp.to_json)
end

def volume_status_node_request_prepare(pool_name, volumes)
  req = Hash(String, VolumeStatusRequestToNode).new

  # TODO: Generate SHD service one per Volume per Storage node
  volumes.each do |volume|
    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        req[storage_unit.node.name] = VolumeStatusRequestToNode.new if req[storage_unit.node.name]?.nil?
        # Generate Service Unit
        storage_unit.service = StorageUnitService.new(volume.name, storage_unit).unit
        req[storage_unit.node.name].storage_units << storage_unit
      end
    end
  end

  req
end

def volume_list_detail_status(env, pool_name, volume_name, state)
  if pool_name == ""
    volumes = Datastore.list_volumes_by_user(env.user_id)
  elsif volume_name.nil?
    volumes = Datastore.list_volumes_by_user(env.user_id, pool_name)
  else
    vol = Datastore.get_volume(pool_name, volume_name)
    raise VolumeNotFound.new("Volume #{volume_name} not found") unless vol

    volumes = [vol]
  end

  return volumes.to_json unless state

  nodes = participating_nodes(pool_name, volumes)

  # Collect list of services and Storage Units
  data = volume_status_node_request_prepare(pool_name, volumes)
  resp = dispatch_action(ACTION_VOLUME_STATUS, pool_name, nodes, data.to_json)

  volumes.each do |volume|
    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        if resp.node_responses[storage_unit.node.id].ok
          node_resp = VolumeStatusRequestToNode.from_json(resp.node_responses[storage_unit.node.id].response)
          node_resp.storage_units.each do |su|
            if su.node.name == storage_unit.node.name && su.path == storage_unit.path
              storage_unit.metrics = su.metrics
            end
          end
        end

        if storage_unit.metrics.health == ""
          set_default_storage_unit_metrics(storage_unit)
        end
      end
    end
  end

  # Post process the Metrics to find Volume Health and Volume Utilization
  volumes.each do |volume|
    set_volume_metrics(volume)
  end

  volume_name.nil? ? volumes.to_json : volumes[0].to_json
end

get "/api/v1/volumes" do |env|
  state = env.params.query["state"]

  volume_list_detail_status(env, "", nil, state ? true : false)
end

get "/api/v1/pools/:pool_name/volumes" do |env|
  pool_name = env.params.url["pool_name"]
  state = env.params.query["state"]

  volume_list_detail_status(env, pool_name, nil, state ? true : false)
rescue ex : VolumeNotFound
  halt(env, status_code: 400, response: ({"error": "#{ex}"}.to_json))
end

get "/api/v1/pools/:pool_name/volumes/:volume_name" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  next forbidden(env) unless Datastore.viewer?(env.user_id, pool_name, volume_name)

  state = env.params.query["state"]

  volume_list_detail_status(env, pool_name, volume_name, state ? true : false)
rescue ex : VolumeNotFound
  halt(env, status_code: 400, response: ({"error": "#{ex}"}.to_json))
end
