require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

REBALNCE_DIR = "/var/lib/kadalu/rebalance"

ACTION_REBALANCE_STATUS = "action_rebalance_status"

# Calculate the status file with highest estimate_seconds and return that file data from node.
node_action ACTION_REBALANCE_STATUS do |data, _env|
  services, volume = ServiceRequestToNodeWithVolume.from_json(data)
  int_min = "-2147483648"
  rebalance_status_file_with_highest_estimate_in_secs = ""
  status_file_path = ""
  rebalance_dir = Path.new(WORKDIR, "rebalance", "#{volume.name}").to_s
  node_resp = Hash(String, MoanaTypes::MigrateDataRebalanceStatus).new

  unless services[GlobalConfig.local_node.id]?.nil?
    services[GlobalConfig.local_node.id].each do |service|
      svc = Service.from_json(service.to_json)
      puts "svc: #{svc}"
      # TODO: Add check for svc.running?
      if svc.name == "migratedataservice"
        status_file_path = "#{rebalance_dir}/#{svc.id}.json"
        if File.exists?(status_file_path)
          data = MoanaTypes::MigrateDataRebalanceStatus.from_json(File.read(status_file_path))
          puts "data"
          if data.estimate_seconds.to_i64 > int_min.to_i64
            int_min = data.estimate_seconds
            rebalance_status_file_with_highest_estimate_in_secs = status_file_path
          end
        end
      end
    end
  end

  if rebalance_status_file_with_highest_estimate_in_secs != ""
    node_resp[GlobalConfig.local_node.id] = MoanaTypes::MigrateDataRebalanceStatus.from_json(File.read(rebalance_status_file_with_highest_estimate_in_secs))
    NodeResponse.new(true, node_resp.to_json)
  else
    NodeResponse.new(true, (node_resp[GlobalConfig.local_node.id] = MoanaTypes::MigrateDataRebalanceStatus.new).to_json)
  end
end

get "/api/v1/pools/:pool_name/volumes/:volume_name/rebalance_status" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name, volume_name))

  volume = Datastore.get_volume(pool_name, volume_name)
  api_exception(volume.nil?, {"error": "Volume doesn't exists"}.to_json)
  volume = volume.not_nil!
  pool = volume.not_nil!.pool

  nodes = participating_nodes(pool_name, volume)

  # TODO: Add to missed_ops if a node is not reachable [Check if this is required, since node ping check is done]

  # Validate if all the nodes are reachable.
  resp = dispatch_action(ACTION_PING, pool_name, nodes, "")
  api_exception(!resp.ok, node_errors("Not all participant nodes are reachable", resp.node_responses).to_json)

  services = construct_migrate_data_service_request(volume)

  resp = dispatch_action(
    ACTION_REBALANCE_STATUS,
    pool_name,
    nodes,
    {services, volume}.to_json
  )

  api_exception(!resp.ok, node_errors("Failed to get rebalance status of volume #{volume.name}", resp.node_responses).to_json)

  # Goto every participating node of volume's workdir/rebalance/volume_name
  # Fetch the highest estimate seconds value in that node
  # construct status data which is highest estimate seconds of all nodes.
  # Return by adding Rebalances status to Class Volume or Class StorageUnit in JSON

  # Constraints
  # How to show migrate-data has crashed [when svc.running? is false and complete: false]

  # nodes.each do |node|
  # 	puts "resp: #{resp}"
  # end
  puts "resp1: #{resp}"

  env.response.status_code = 200
  volume.to_json
end
