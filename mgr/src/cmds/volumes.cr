require "./helpers"
require "./volume_create_parser"
require "./gluster_volume_parser"

struct VolumeArgs
  property status = false, detail = false, name = "", volume_id = "", no_start = false,
    auto_create_pool = false, auto_add_nodes = false, options = "",
    node_maps = Hash(String, String).new
end

class Args
  property volume_args = VolumeArgs.new
end

def pool_and_volume_name(value)
  pool_name, _, volume_name = value.partition("/")
  {pool_name, volume_name}
end

command "volume.create", "Kadalu Storage Volume Create" do |parser, args|
  parser.banner = "Usage: kadalu volume create POOL/VOLNAME TYPE STORAGE_UNITS [arguments]"
  parser.on("--no-start", "Don't start the Volume on Create") do
    args.volume_args.no_start = true
  end
  parser.on("--volume-id=ID", "Set Volume ID to import a Volume") do |volume_id|
    args.volume_args.volume_id = volume_id
  end
  parser.on("--auto-create-pool", "Auto create Pool if not exists") do
    args.volume_args.auto_create_pool = true
  end
  parser.on("--auto-add-nodes", "Automatically add nodes to the Pool") do
    args.volume_args.auto_add_nodes = true
  end
  parser.on("--node-map=NODEMAP", "Provide Node mapping while importing. Example: --node-map=\"server1.example.com=node1.example.com\"") do |node|
    old_name, new_name = node.split("=")
    args.volume_args.node_maps[old_name] = new_name
  end
end

handler "volume.create" do |args|
  begin
    # Handle Gluster Volume import
    command_error "Pool name is required" if args.pos_args.size == 0

    pool_name, volume_name = pool_and_volume_name(args.pos_args[0])
    if volume_name == "-"
      import_data = from_gluster_volumes_xml(pool_name, STDIN.gets_to_end, args)
      # TODO: Handle if the input contains more than one Volume
      # TODO: Handle if no Volumes provided
      req = VolumeRequestParser.parse(import_data[0].cli_args)
      req.volume_id = import_data[0].volume_id
      # TODO: How to use import_data[0].options
    else
      req = VolumeRequestParser.parse(args.pos_args)
      req.volume_id = args.volume_args.volume_id
    end

    req.no_start = args.volume_args.no_start
    req.auto_create_pool = args.volume_args.auto_create_pool
    req.auto_add_nodes = args.volume_args.auto_add_nodes
    args.pool_name = req.pool.name
    api_call(args, "Failed to Create Volume") do |client|
      volume = client.pool(args.pool_name).create_volume(req)

      handle_json_output(volume, args)

      puts "Volume #{req.name} created successfully"
      puts "ID: #{volume.id}"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Volume create failed"
    STDERR.puts ex
    exit 1
  end
end

command "volume.start", "Start the Kadalu Storage Volume" do |parser, _|
  parser.banner = "Usage: kadalu volume start POOL/VOLNAME [arguments]"
end

handler "volume.start" do |args|
  begin
    args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
    api_call(args, "Failed to Start the Volume") do |client|
      volume = client.pool(args.pool_name).volume(volume_name).start

      handle_json_output(volume, args)

      puts "Volume #{volume.name} started successfully"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Volume start failed"
    STDERR.puts ex
    exit 1
  end
end

command "volume.stop", "Stop the Kadalu Storage Volume" do |parser, _|
  parser.banner = "Usage: kadalu volume stop POOL/VOLNAME [arguments]"
end

handler "volume.stop" do |args|
  begin
    args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
    next unless (args.script_mode || yes("Are you sure you want to stop the Volume?"))

    api_call(args, "Failed to Stop the Volume") do |client|
      volume = client.pool(args.pool_name).volume(volume_name).stop

      handle_json_output(volume, args)

      puts "Volume #{volume.name} stopped successfully"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Volume stop failed"
    STDERR.puts ex
    exit 1
  end
end

command "volume.list", "Volumes list of a Kadalu Storage Pool" do |parser, args|
  parser.banner = "Usage: kadalu volume list POOL [arguments]"
  parser.on("--status", "Show Volumes states") do
    args.volume_args.status = true
  end
  parser.on("--detail", "Show detailed Volumes info") do
    args.volume_args.detail = true
  end
end

def volume_detail(volume, status = false)
  health = volume.state == "Started" && status ? "#{volume.state} (#{volume.metrics.health})" : volume.state

  puts "Name                    : #{volume.pool.name}/#{volume.name}"
  puts "Type                    : #{volume.type}"
  puts "ID                      : #{volume.id}"
  puts "State                   : #{health}"
  puts "Size                    : #{(volume.metrics.size_used_bytes + volume.metrics.size_free_bytes).humanize_bytes}"
  puts "Inodes                  : #{(volume.metrics.inodes_used_count + volume.metrics.inodes_free_count).humanize}"
  puts "Utilization             : #{volume.metrics.size_used_bytes.humanize_bytes}/#{(volume.metrics.size_used_bytes + volume.metrics.size_free_bytes).humanize_bytes}" if status
  puts "Utilization (Inodes)    : #{volume.metrics.inodes_used_count.humanize}/#{(volume.metrics.inodes_used_count + volume.metrics.inodes_free_count).humanize}" if status
  puts "Options                 :#{volume.options.size > 0 ? "" : " -"}"

  volume.options.each do |k, v|
    printf("    %20s: %s\n", k, v)
  end
  puts "Number of Storage units : #{volume.distribute_groups.size * volume.distribute_groups[0].storage_units.size}"
  volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
    printf("Distribute Group %-2s     :%s\n", grp_idx + 1, status ? " Health: #{dist_grp.metrics.health}" : "")
    dist_grp.storage_units.each_with_index do |storage_unit, idx|
      printf(
        "    Storage Unit %-3s    : %s:%s (Port: %s%s)\n",
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

handler "volume.list" do |args|
  args.pool_name, args.volume_args.name = pool_and_volume_name(args.pos_args.size < 1 ? "" : args.pos_args[0])

  api_call(args, "Failed to get list of volumes") do |client|
    if args.pool_name == ""
      volumes = client.list_volumes(state: args.volume_args.status)
    elsif args.volume_args.name == ""
      volumes = client.pool(args.pool_name).list_volumes(state: args.volume_args.status)
    else
      volumes = [client.pool(args.pool_name).volume(args.volume_args.name).get(state: args.volume_args.status)]
    end

    handle_json_output(volumes, args)

    if volumes.size == 0
      puts "No Volumes available in the Pool. Run `kadalu volume create #{args.pool_name == "" ? "<pool>" : args.pool_name}/<volume-name> ...` to create a volume."
    end

    if args.volume_args.detail
      volumes.each do |volume|
        volume_detail(volume, args.volume_args.status)
      end

      next
    end

    table = CliTable.new(6)
    table.right_align(5)
    table.right_align(6)
    if args.volume_args.status
      table.header("Name", "ID", "State", "Type", "Utilization", "Utilization(Inodes)")
    else
      table.header("Name", "ID", "State", "Type", "Size", "Inodes")
    end

    volumes.each do |volume|
      if args.volume_args.status
        table.record(
          "#{volume.pool.name}/#{volume.name}",
          volume.id,
          volume.state == "Started" ? "#{volume.state} (#{volume.metrics.health})" : volume.state,
          volume.type,
          "#{volume.metrics.size_used_bytes.humanize_bytes}/#{volume.metrics.size_bytes.humanize_bytes}",
          "#{volume.metrics.inodes_used_count.humanize}/#{volume.metrics.inodes_count.humanize}"
        )
      else
        table.record(
          "#{volume.pool.name}/#{volume.name}",
          volume.id,
          volume.state,
          volume.type,
          volume.metrics.size_bytes.humanize_bytes,
          volume.metrics.inodes_count.humanize
        )
      end
    end

    table.render
  end
end

command "volume.delete", "Delete the Kadalu Storage Volume" do |parser, _|
  parser.banner = "Usage: kadalu volume delete POOL/VOLNAME [arguments]"
end

handler "volume.delete" do |args|
  args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
  next unless (args.script_mode || yes("Are you sure you want to delete the Volume?"))

  api_call(args, "Failed to Delete the Volume") do |client|
    client.pool(args.pool_name).volume(volume_name).delete

    handle_json_output(nil, args)
    puts "Volume #{volume_name} deleted successfully"
  end
end

command "volume.set", "Set options to the Kadalu Storage Volume" do |parser, args|
  parser.banner = "Usage: kadalu volume set POOL/VOLNAME [arguments]"

  parser.on("--options=options", "Set the options") do |options|
    args.volume_args.options = options
    # puts "options", options
  end
  # parser.on("--volume-id=ID", "Set Volume ID to import a Volume") do |volume_id|
  #   args.volume_args.volume_id = volume_id
  # end
end

handler "volume.set" do |args|
  args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")

  volume_options = validate_volume_options(args.volume_args.options)
  # without .to_json to conserve HASH.
  puts "here", volume_options.to_json.to_s
  puts "here", typeof(volume_options.to_s)

  api_call(args, "Failed to Set options to the Volume") do |client|
    puts "in cmd", args.volume_args.options
    volume = client.pool(args.pool_name).volume(volume_name).set(volume_options.to_json.to_s)

    handle_json_output(volume, args)
    puts "Volume #{volume_name} options set successfully"
  end
end
