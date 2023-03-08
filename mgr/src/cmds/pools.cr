require "./helpers"
require "./pool_create_parser"
require "./gluster_volume_parser"

struct PoolArgs
  property status = false, detail = false, name = "", pool_id = "", no_start = false,
    auto_add_nodes = false,
    node_maps = Hash(String, String).new, volfiles_separator = " "
end

class Args
  property pool_args = PoolArgs.new
end

command "pool.create", "Kadalu Storage Pool Create" do |parser, args|
  parser.banner = "Usage: kadalu pool create NAME TYPE STORAGE_UNITS [arguments]"
  parser.on("--no-start", "Don't start the pool upon creation") do
    args.pool_args.no_start = true
  end
  parser.on("--pool-id=ID", "Set pool-id to import a pool") do |pool_id|
    args.pool_args.pool_id = pool_id
  end
  parser.on("--auto-add-nodes", "Automatically add nodes to the pool") do
    args.pool_args.auto_add_nodes = true
  end
  parser.on("--node-map=NODEMAP", "Provide node mapping while importing.\nExample: --node-map=\"server1.example.com=node1.example.com\"") do |node|
    old_name, new_name = node.split("=")
    args.pool_args.node_maps[old_name] = new_name
  end
end

handler "pool.create" do |args|
  begin
    # Handle Gluster Pool import
    command_error "Pool name is required" if args.pos_args.size == 0

    pool_name = args.pos_args[0]
    if pool_name == "-"
      import_data = from_gluster_volumes_xml(STDIN.gets_to_end, args)
      # TODO: Handle if the input contains more than one Pool
      # TODO: Handle if no Pools provided
      req = PoolRequestParser.parse(import_data[0].cli_args)
      req.pool_id = import_data[0].volume_id
      # TODO: How to use import_data[0].options
    else
      req = PoolRequestParser.parse(args.pos_args)
      req.pool_id = args.pool_args.pool_id
    end

    req.no_start = args.pool_args.no_start
    req.auto_add_nodes = args.pool_args.auto_add_nodes
    api_call(args, "Failed to create pool") do |client|
      pool = client.create_pool(req)

      handle_json_output(pool, args)

      puts "Pool #{req.name} created"
      puts "ID: #{pool.id}"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Pool create failed"
    STDERR.puts ex
    exit 1
  end
end

command "pool.start", "Start the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool start POOL_NAME [arguments]"
end

handler "pool.start" do |args|
  begin
    command_error "Pool name is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
    api_call(args, "Failed to start the pool") do |client|
      pool = client.pool(pool_name).start

      handle_json_output(pool, args)

      puts "Pool #{pool.name} started"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Pool start failed"
    STDERR.puts ex
    exit 1
  end
end

command "pool.stop", "Stop the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool stop POOL_NAME [arguments]"
end

handler "pool.stop" do |args|
  begin
    command_error "Pool name is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
    next unless (args.script_mode || yes("Are you sure you want to stop the pool? [y/N]"))

    api_call(args, "Failed to stop the pool.") do |client|
      pool = client.pool(pool_name).stop

      handle_json_output(pool, args)

      puts "Pool #{pool.name} stopped"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Pool stop failed"
    STDERR.puts ex
    exit 1
  end
end

command "pool.list", "Pools list of a Kadalu Storage pool" do |parser, args|
  parser.banner = "Usage: kadalu pool list [POOL_NAME] [arguments]"
  parser.on("--status", "Show Pools states") do
    args.pool_args.status = true
  end
  parser.on("--detail", "Show detailed pool info") do
    args.pool_args.detail = true
  end
  parser.on("-s SEP", "--volfiles-seperator=SEP", "Separator for Volfile List (Default is space)") do |sep|
    args.pool_args.volfiles_separator = sep
  end
end

def pool_detail(pool, args)
  status = args.pool_args.status
  health = pool.state == "Started" && status ? "#{pool.state} (#{pool.metrics.health})" : pool.state

  volfile_servers = [] of String
  pool.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      volfile_servers << "#{storage_unit.node.name}:#{storage_unit.port}"
    end
  end

  puts "Name                    : #{pool.name}"
  puts "Type                    : #{pool.type}"
  puts "ID                      : #{pool.id}"
  puts "State                   : #{health}"
  puts "Size                    : #{(pool.metrics.size_used_bytes + pool.metrics.size_free_bytes).humanize_bytes}"
  puts "Inodes                  : #{(pool.metrics.inodes_used_count + pool.metrics.inodes_free_count).humanize}"
  puts "Utilization             : #{pool.metrics.size_used_bytes.humanize_bytes}/#{(pool.metrics.size_used_bytes + pool.metrics.size_free_bytes).humanize_bytes}" if status
  puts "Utilization (Inodes)    : #{pool.metrics.inodes_used_count.humanize}/#{(pool.metrics.inodes_used_count + pool.metrics.inodes_free_count).humanize}" if status
  puts "Volfile Servers         : #{volfile_servers.join(args.pool_args.volfiles_separator)}"
  puts "Options                 :#{pool.options.size > 0 ? "" : " -"}"

  pool.options.each do |k, v|
    printf("    %20s: %s\n", k, v)
  end
  puts "Number of storage units : #{pool.distribute_groups.size * pool.distribute_groups[0].storage_units.size}"
  pool.distribute_groups.each_with_index do |dist_grp, grp_idx|
    printf("Distribute group %-2s     :%s\n", grp_idx + 1, status ? " Health: #{dist_grp.metrics.health}" : "")
    dist_grp.storage_units.each_with_index do |storage_unit, idx|
      printf(
        "    Storage unit %-3s    : %s:%s (Port: %s%s)",
        idx + 1,
        storage_unit.node.name,
        storage_unit.path,
        storage_unit.port,
        status ? ", Health: #{storage_unit.metrics.health}" : ""
      )
      puts
    end
  end

  puts
end

handler "pool.list" do |args|
  args.pool_args.name = args.pos_args.size < 1 ? "" : args.pos_args[0]

  api_call(args, "Failed to get the list of pools") do |client|
    if args.pool_args.name == ""
      pools = client.list_pools(state: args.pool_args.status)
    else
      pools = [client.pool(args.pool_args.name).get(state: args.pool_args.status)]
    end

    handle_json_output(pools, args)

    if pools.size == 0
      puts "No pools available in the Cluster.\nRun `kadalu pool create \"<pool>\" ...` to create a pool."
    end

    if args.pool_args.detail
      pools.each do |pool|
        pool_detail(pool, args)
      end

      next
    end

    table = CliTable.new(6)
    table.right_align(5)
    table.right_align(6)
    if args.pool_args.status
      table.header("Name", "ID", "State", "Type", "Utilization", "Utilization(Inodes)")
    else
      table.header("Name", "ID", "State", "Type", "Size", "Inodes")
    end

    pools.each do |pool|
      if args.pool_args.status
        table.record(
          "#{pool.name}",
          pool.id,
          pool.state == "Started" ? "#{pool.state} (#{pool.metrics.health})" : pool.state,
          pool.type,
          "#{pool.metrics.size_used_bytes.humanize_bytes}/#{pool.metrics.size_bytes.humanize_bytes}",
          "#{pool.metrics.inodes_used_count.humanize}/#{pool.metrics.inodes_count.humanize}"
        )
      else
        table.record(
          "#{pool.name}",
          pool.id,
          pool.state,
          pool.type,
          pool.metrics.size_bytes.humanize_bytes,
          pool.metrics.inodes_count.humanize
        )
      end
    end

    table.render
  end
end

command "pool.delete", "Delete the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool delete POOL_NAME [arguments]"
end

handler "pool.delete" do |args|
  pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
  next unless (args.script_mode || yes("Are you sure you want to delete the pool? [y/N]"))

  api_call(args, "Failed to delete the pool") do |client|
    client.pool(pool_name).delete

    handle_json_output(nil, args)
    puts "Pool #{pool_name} deleted"
  end
end

command "pool.set", "Set options to the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool set POOL_NAME [arguments]"
end

handler "pool.set" do |args|
  command_error "Pool name is required" if args.pos_args.size == 0
  pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""

  command_error "No pool options have been passed." if args.pos_args.size < 3

  pool_options = validate_pool_options(args.pos_args[1..])

  api_call(args, "Failed to Set options to the pool") do |client|
    pool = client.pool(pool_name).set(pool_options)

    handle_json_output(pool, args)
    puts "Pool #{pool_name} options set"
  end
end

command "pool.reset", "Reset the options of the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool reset POOL_NAME [arguments]"
end

handler "pool.reset" do |args|
  command_error "Pool name is required" if args.pos_args.size == 0
  pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""

  command_error "No pool options have been passed." if args.pos_args.size < 3

  api_call(args, "Failed to set options to the pool") do |client|
    pool = client.pool(pool_name).reset(args.pos_args[1..])

    handle_json_output(pool, args)
    puts "Pool #{pool_name} options reset"
  end
end

command "pool.rename", "Rename the Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu pool rename POOL_NAME NEW_POOL_NAME [arguments]"
end

handler "pool.rename" do |args|
  if args.pos_args.size < 2
    puts "POOL_NAME NEW_POOL_NAME is required"
    exit(0)
  end

  pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
  new_pool_name = args.pos_args.size > 1 ? args.pos_args[1] : ""

  api_call(args, "Failed to rename the pool") do |client|
    pool = client.pool(pool_name).rename(new_pool_name)

    handle_json_output(pool, args)
    puts "Pool #{pool_name} renamed to #{new_pool_name} successfully!"
  end
end

command "pool.expand", "Kadalu Storage Pool Expand" do |parser, args|
  parser.banner = "Usage: kadalu pool expand POOL_NAME TYPE STORAGE_UNITS [arguments]"
  parser.on("--auto-add-nodes", "Automatically add nodes to the Pool") do
    args.pool_args.auto_add_nodes = true
  end
  parser.on("--node-map=NODEMAP", "Provide Node mapping while importing. Example: --node-map=\"server1.example.com=node1.example.com\"") do |node|
    old_name, new_name = node.split("=")
    args.pool_args.node_maps[old_name] = new_name
  end
end

handler "pool.expand" do |args|
  begin
    command_error "Pool name is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""

    req = PoolRequestParser.parse(args.pos_args)

    req.auto_add_nodes = args.pool_args.auto_add_nodes

    api_call(args, "Failed to Expand Pool") do |client|
      pool = client.pool(pool_name).expand(req)

      handle_json_output(pool, args)

      puts "Pool #{req.name} expanded successfully"
      puts "ID: #{pool.id}"

      puts "Proceed to the rebalancing of pool #{req.name} by following the below steps."
      puts "To start the rebalancing of pool: `kadalu rebalance start #{pool_name}`"
      puts "To force stop the rebalancing of pool: `kadalu rebalnce stop #{pool_name}`"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Pool expand failed"
    STDERR.puts ex
    exit 1
  end
end
