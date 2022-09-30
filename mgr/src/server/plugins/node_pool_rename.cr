require "./helpers"
require "../conf"
require "./volume_utils.cr"

ACTION_NODE_POOL_RENAME = "node_pool_rename"

node_action ACTION_NODE_POOL_RENAME do |data, _env|
  puts "data: #{data}, typeof: #{typeof(data)}"
  data = Hash(String, String).from_json(data)
  new_pool_name = data["new_pool_name"]

  puts "globalconfig: #{GlobalConfig.local_node}"
  puts "globalconfig node name: #{GlobalConfig.local_node.name}"

  data_file = Path.new(GlobalConfig.workdir, "info")
  if !File.exists?(data_file)
    next NodeResponse.new(false, {"error": "Node info file is not found in #{GlobalConfig.local_node.name}. Restart kadalu-mgr to regenerate the info file"}.to_json)
  end

  local_node_data = LocalNodeData.from_json(File.read(data_file))
  # if local_node_data.pool_name != ""
  #   msg = local_node_data.pool_name == old_pool_name ? "the " : "a different "
  #   next NodeResponse.new(false, {"error": "Node is already part of #{msg} Pool"}.to_json)
  # end

  local_node_data.pool_name = new_pool_name
  File.write(data_file, local_node_data.to_json)

  GlobalConfig.local_node = local_node_data
  NodeResponse.new(true, "")
end
