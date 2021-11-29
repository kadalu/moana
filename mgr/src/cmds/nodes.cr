require "./helpers"

struct NodeArgs
  property status = false
end

class Args
  property node_args = NodeArgs.new
end

command "node.join", "Join a node to Kadalu Storage Cluster" do |parser, args|
  parser.banner = "Usage: kadalu node join NAME ENDPOINT [arguments]"
  parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
    args.cluster_name = name
  end
end

handler "node.join" do |args|
  if args.pos_args.size < 2
    STDERR.puts "Node name and Node endpoint are required."
    exit 1
  end

  # TODO: Add default Cluster logic once it is available
  if args.cluster_name == ""
    STDERR.puts "--cluster=NAME is required."
    exit 1
  end

  name = args.pos_args[0]
  endpoint = args.pos_args[1]
  api_call(args, "Failed to join the Node") do |client|
    node = client.cluster(args.cluster_name).join_node(name, endpoint)
    puts "Node #{name}(#{endpoint}) joined to #{args.cluster_name} successfully"
    puts "ID: #{node.id}"
  end
end

command "node.list", "Nodes list of a Kadalu Storage Cluster" do |parser, args|
  parser.banner = "Usage: kadalu node list [arguments]"
  parser.on("-c NAME", "--cluster=NAME", "Cluster name") do |name|
    args.cluster_name = name
  end
  parser.on("--status", "Show nodes states") do
    args.node_args.status = true
  end
end

handler "node.list" do |args|
  if args.cluster_name == ""
    STDERR.puts "--cluster=NAME is required."
    exit 1
  end

  api_call(args, "Failed to get list of nodes") do |client|
    nodes = client.cluster(args.cluster_name).list_nodes(state: args.node_args.status)
    puts "No nodes added to the Cluster. Run `kadalu node join -c #{args.cluster_name} <node-name> <node-endpoint>` to add a node." if nodes.size == 0

    if args.node_args.status
      printf("%36s  %6s  %20s  %s\n", "ID", "State", "Name", "Endpoint")
    else
      printf("%36s  %20s  %s\n", "ID", "Name", "Endpoint")
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
