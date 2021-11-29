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
    puts "Cluster #{name} created successfully"
    puts "ID: #{cluster.id}"
  end
end

command "cluster.list", "Kadalu Storage Clusters List" do |parser, _|
  parser.banner = "Usage: kadalu cluster list [arguments]"
end

handler "cluster.list" do |args|
  api_call(args, "Failed to get the list of Clusters") do |client|
    clusters = client.list_clusters

    puts "No clusters. Run `kadalu cluster create <name>` to create a Cluster." if clusters.size == 0

    printf("%36s  %s\n", "ID", "Name")

    clusters.each do |cluster|
      printf("%36s  %s\n", cluster.id, cluster.name)
    end
  end
end
