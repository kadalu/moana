require "./helpers"

command "heal.start", "Start the Kadalu Storage Volume heal" do |parser, _|
  parser.banner = "Usage: kadalu heal start POOL/VOLNAME"
end

handler "heal.start" do |args|
  command_error "Pool name is required" if args.pos_args.size == 0
  pool_name, volume_name = pool_and_volume_name(args.pos_args[0])

  api_call(args, "Failed to start healing Volume") do |client|
    volume = client.pool(pool_name).volume(volume_name).heal_start

    handle_json_output(volume, args)

    puts "Volume #{volume_name} healed successfully! \n"

    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        puts "\n"
        puts "Storage Unit                       :       #{storage_unit.node.name}:#{storage_unit.path}"
        puts " Status                            :       #{storage_unit.heal_metrics.heal_status}"
        puts " Total Number of entries           :       #{storage_unit.heal_metrics.heal_total}"
      end
    end
  end
end

command "heal.info", "Get the Kadalu Storage Volume heal info" do |parser, _|
  parser.banner = "Usage: kadalu heal info POOL/VOLNAME"
end

handler "heal.info" do |args|
  command_error "Pool name is required" if args.pos_args.size == 0
  pool_name, volume_name = pool_and_volume_name(args.pos_args[0])

  api_call(args, "Failed to get heal info for Volume") do |client|
    volume = client.pool(pool_name).volume(volume_name).heal_info

    handle_json_output(volume, args)

    puts "Volume info-summary of #{volume_name} \n"

    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        puts "\n"
        puts "Storage Unit                       :       #{storage_unit.node.name}:#{storage_unit.path}"
        puts " Status                            :       #{storage_unit.heal_metrics.heal_status}"
        puts " Total Number of entries           :       #{storage_unit.heal_metrics.heal_total}"
        puts " Number of entries in heal pending :       #{storage_unit.heal_metrics.heal_pending_count}"
        puts " Number of entries in split-brain  :       #{storage_unit.heal_metrics.heal_split_brain_count}"
        puts " Number of entries possibly healing:       #{storage_unit.heal_metrics.heal_possibly_healing_count}"
      end
    end
  end
end
