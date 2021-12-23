require "./helpers"

struct NodeArgs
  property status = false, endpoint = ""
end

class Args
  property node_args = NodeArgs.new
end

command "node.add", "Add a node to Kadalu Storage Pool" do |parser, args|
  parser.banner = "Usage: kadalu node add POOL/NAME ENDPOINT [arguments]"
  parser.on("--endpoint", "Node Endpoint. Default is http://<nodename>:3000") do |endpoint|
    args.node_args.endpoint = endpoint
  end
end

def pool_and_node_name(value)
  parts = value.split("/")
  return {parts[0], parts[1]} if parts.size == 2

  {parts[0], ""}
end

handler "node.add" do |args|
  args.pool_name, name = pool_and_node_name(args.pos_args.size < 1 ? "" : args.pos_args[0])
  if args.pool_name == ""
    STDERR.puts "Pool name is required."
    exit 1
  end

  if name == ""
    STDERR.puts "Node name is required."
    exit 1
  end

  api_call(args, "Failed to add the Node") do |client|
    node = client.pool(args.pool_name).add_node(name, args.node_args.endpoint)
    puts "Node #{name} added to #{args.pool_name} successfully"
    puts "ID: #{node.id}"
  end
end

command "node.list", "Nodes list of a Kadalu Storage Pool" do |parser, args|
  parser.banner = "Usage: kadalu node list POOL [arguments]"
  parser.on("--status", "Show nodes states") do
    args.node_args.status = true
  end
end

handler "node.list" do |args|
  args.pool_name, _ = pool_and_node_name(args.pos_args.size < 1 ? "" : args.pos_args[0])

  api_call(args, "Failed to get list of nodes") do |client|
    if args.pool_name == ""
      nodes = client.list_nodes(state: args.node_args.status)
    else
      nodes = client.pool(args.pool_name).list_nodes(state: args.node_args.status)
    end
    puts "No nodes added to the Pool. Run `kadalu node add #{args.pool_name}/<node-name>` to add a node." if nodes.size == 0

    if args.node_args.status
      table = CliTable.new(4)
      table.header("Name", "ID", "State", "Endpoint")
    else
      table = CliTable.new(3)
      table.header("Name", "ID", "Endpoint")
    end

    nodes.each do |node|
      if args.node_args.status
        table.record("#{node.pool.name}/#{node.name}", node.id, node.state, node.endpoint)
      else
        table.record("#{node.pool.name}/#{node.name}", node.id, node.endpoint)
      end
    end

    table.render
  end
end
