require "./helpers"

struct NodeArgs
  property status = false, endpoint = ""
end

class Args
  property node_args = NodeArgs.new
end

command "node.join", "Join a node to Kadalu Storage Cluster" do |parser, args|
  parser.banner = "Usage: kadalu node join CLUSTER/NAME ENDPOINT [arguments]"
  parser.on("--endpoint", "Node Endpoint. Default is http://<nodename>:3000") do |endpoint|
    args.node_args.endpoint = endpoint
  end
end

def cluster_and_node_name(value)
  parts = value.split("/")
  return {parts[0], parts[1]} if parts.size == 2

  {parts[0], ""}
end

handler "node.join" do |args|
  args.cluster_name, name = cluster_and_node_name(args.pos_args.size < 1 ? "" : args.pos_args[0])
  if args.cluster_name == ""
    STDERR.puts "Cluster name is required."
    exit 1
  end

  if name == ""
    STDERR.puts "Node name is required."
    exit 1
  end

  api_call(args, "Failed to join the Node") do |client|
    node = client.cluster(args.cluster_name).join_node(name, args.node_args.endpoint)
    puts "Node #{name} joined to #{args.cluster_name} successfully"
    puts "ID: #{node.id}"
  end
end

command "node.list", "Nodes list of a Kadalu Storage Cluster" do |parser, args|
  parser.banner = "Usage: kadalu node list CLUSTER [arguments]"
  parser.on("--status", "Show nodes states") do
    args.node_args.status = true
  end
end

handler "node.list" do |args|
  args.cluster_name, _ = cluster_and_node_name(args.pos_args.size < 1 ? "" : args.pos_args[0])
  if args.cluster_name == ""
    STDERR.puts "Cluster name is required."
    exit 1
  end

  api_call(args, "Failed to get list of nodes") do |client|
    nodes = client.cluster(args.cluster_name).list_nodes(state: args.node_args.status)
    puts "No nodes added to the Cluster. Run `kadalu node join #{args.cluster_name}/<node-name>` to add a node." if nodes.size == 0

    if args.node_args.status
      printf("%36s  %6s  %20s  %s\n", "ID", "State", "Name", "Endpoint") if nodes.size > 0
    else
      printf("%36s  %20s  %s\n", "ID", "Name", "Endpoint") if nodes.size > 0
    end

    nodes.each do |node|
      if args.node_args.status
        printf("%36s  %6s  %20s  %s\n", node.id, node.state, node.name, node.endpoint)
      else
        printf("%36s  %20s  %s\n", node.id, node.name, node.endpoint)
      end
    end
  end
end
