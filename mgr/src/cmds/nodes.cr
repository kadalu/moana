require "./helpers"

struct NodeArgs
  property status = false, endpoint = ""
end

class Args
  property node_args = NodeArgs.new
end

command "node.add", "Add a node to Kadalu Storage cluster" do |parser, args|
  parser.banner = "Usage: kadalu node add NAME [arguments]"
  parser.on("--endpoint", "Node endpoint. Default is http://<nodename>:3000") do |endpoint|
    args.node_args.endpoint = endpoint
  end
end

command "node.create", "Add a node to Kadalu Storage cluster (alias to node add)" do |parser, args|
  parser.banner = "Usage: kadalu node create NAME [arguments]"
  parser.on("--endpoint", "Node endpoint. Default is http://<nodename>:3000") do |endpoint|
    args.node_args.endpoint = endpoint
  end
end

def node_add_handler(args)
  name = args.pos_args.size < 1 ? "" : args.pos_args[0]
  if name == ""
    STDERR.puts "Node name is required."
    exit 1
  end

  api_call(args, "Failed to add the node") do |client|
    node = client.add_node(name, args.node_args.endpoint)

    handle_json_output(node, args)

    puts "Node #{name} added to the cluster"
    puts "ID: #{node.id}"
  end
end

handler "node.add" do |args|
  node_add_handler(args)
end

handler "node.create" do |args|
  node_add_handler(args)
end

command "node.list", "Nodes list of a Kadalu Storage cluster" do |parser, args|
  parser.banner = "Usage: kadalu node list [arguments]"
  parser.on("--status", "Show nodes states") do
    args.node_args.status = true
  end
end

handler "node.list" do |args|
  api_call(args, "Failed to get list of nodes") do |client|
    nodes = client.list_nodes(state: args.node_args.status)

    handle_json_output(nodes, args)

    puts "No nodes found in the cluster.\nRun `kadalu node add <node-name>` to add a node." if nodes.size == 0

    if args.node_args.status
      table = CliTable.new(4)
      table.header("Name", "ID", "State", "Endpoint")
    else
      table = CliTable.new(3)
      table.header("Name", "ID", "Endpoint")
    end

    nodes.each do |node|
      if args.node_args.status
        table.record("#{node.name}", node.id, node.state, node.endpoint)
      else
        table.record("#{node.name}", node.id, node.endpoint)
      end
    end

    table.render
  end
end

command "node.remove", "Delete the Kadalu Storage Node" do |parser, _|
  parser.banner = "Usage: kadalu node remove NODENAME [arguments]"
end

command "node.delete", "Delete the Kadalu Storage Node (alias to node remove)" do |parser, _|
  parser.banner = "Usage: kadalu node delete NODENAME [arguments]"
end

def node_remove_handler(args)
  node_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
  return unless (args.script_mode || yes("Are you sure you want to remove the node from the pool?"))

  api_call(args, "Failed to remove the node") do |client|
    client.node(node_name).delete
    handle_json_output(nil, args)
    puts "Node #{node_name} removed from the pool"
  end
end

handler "node.remove" do |args|
  node_remove_handler(args)
end

handler "node.delete" do |args|
  node_remove_handler(args)
end
