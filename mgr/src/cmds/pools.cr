require "./helpers"

command "pool.create", "Create the Kadalu Storage Pool" do |parser, _|
  parser.banner = "Usage: kadalu pool create NAME [arguments]"
end

handler "pool.create" do |args|
  if args.pos_args.size < 1
    STDERR.puts "Pool name is required."
    exit 1
  end

  name = args.pos_args[0]
  api_call(args, "Failed to create the Pool") do |client|
    pool = client.create_pool(name)
    puts "Pool #{name} created successfully"
    puts "ID: #{pool.id}"
  end
end

command "pool.list", "Kadalu Storage Pools List" do |parser, _|
  parser.banner = "Usage: kadalu pool list [arguments]"
end

handler "pool.list" do |args|
  api_call(args, "Failed to get the list of Pools") do |client|
    pools = client.list_pools

    puts "No pools. Run `kadalu pool create <name>` to create a Pool." if pools.size == 0

    printf("%36s  %s\n", "ID", "Name") if pools.size > 0

    pools.each do |pool|
      printf("%36s  %s\n", pool.id, pool.name)
    end
  end
end
