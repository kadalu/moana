require "./helpers"

command "node.uptime", "Nodes Uptime" do |parser, _|
  parser.banner = "Usage: kadalu node uptime POOL"
end

handler "node.uptime" do |args|
  args.pool_name, _ = pool_and_node_name(args.pos_args.size < 1 ? "" : args.pos_args[0])

  command_error "Pool name is required" if args.pool_name == ""

  api_call(args, "Failed to get list of nodes") do |client|
    nodes = client.pool(args.pool_name).nodes_uptime

    table = CliTable.new(2)
    table.header("Name", "Uptime")

    nodes.each do |node|
      table.record("#{node.pool.name}/#{node.name}", node.uptime)
    end

    table.render
  end
end
