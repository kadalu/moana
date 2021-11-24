require "./helpers"

command "cluster.create", "Create the Kadalu Storage Cluster" do |parser, _|
  parser.banner = "Usage: kadalu cluster create NAME [arguments]"
end

handler "cluster.create" do |args|
  if args.pos_args.size < 1
    STDERR.puts "Cluster name is required."
    exit 1
  end

  name = args.pos_args[0]
  api_call(args, "Failed to create the Cluster") do |client|
    cluster = client.create_cluster(name)
    puts "Clustere #{name} created successfully"
    puts "ID: #{cluster.id}"
  end
end
