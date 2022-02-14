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

    handle_json_output(pool, args)

    puts "Pool #{name} created successfully"
    puts "ID: #{pool.id}"
  end
end

command "pool.list", "Kadalu Storage Pools List" do |parser|
  parser.banner = "Usage: kadalu pool list [arguments]"
end

handler "pool.list" do |args|
  api_call(args, "Failed to get the list of Pools") do |client|
    pools = client.list_pools

    handle_json_output(pools, args)

    puts "No pools. Run `kadalu pool create <name>` to create a Pool." if pools.size == 0

    table = CliTable.new(2)
    table.header("Name", "ID")
    pools.each do |pool|
      table.record(pool.name, pool.id)
    end

    table.render
  end
end

command "pool.delete", "Delete the Kadalu Storage Pool" do |parser, _|
  parser.banner = "Usage: kadalu pool delete POOL [arguments]"
end

handler "pool.delete" do |args|
  command_error "Pool name is required" if args.pos_args.size < 1
  args.pool_name = args.pos_args[0]

  next unless (args.script_mode || yes("Are you sure you want to delete the Pool?"))

  api_call(args, "Failed to Delete the Pool") do |client|
    pool = client.pool(args.pool_name).delete
    handle_json_output(pool, args)
    puts "Pool #{args.pool_name} deleted"
  end
end
