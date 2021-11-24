require "./helpers"

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
