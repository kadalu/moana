require "./helpers"

struct RebalanceArgs
  property detail = false
end

class Args
  property rebalance_args = RebalanceArgs.new
end

command "rebalance.start", "Start Rebalancing Kadalu Storage volume" do |parser, _|
  parser.banner = "Usage: kadalu rebalance start POOL/VOLNAME [arguments]"
end

handler "rebalance.start" do |args|
  begin
    command_error "Pool/Volname is required" if args.pos_args.size == 0
    args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
    api_call(args, "Failed to start rebalancing of volume") do |client|
      volume = client.pool(args.pool_name).volume(volume_name).rebalance_start

      handle_json_output(volume, args)

      puts "Rebalance of Volume #{volume.name} started"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Starting of volume rebalance failed"
    STDERR.puts ex
    exit 1
  end
end

command "rebalance.stop", "Stop Rebalancing Kadalu Storage volume" do |parser, _|
  parser.banner = "Usage: kadalu rebalance stop POOL/VOLNAME [arguments]"
end

handler "rebalance.stop" do |args|
  begin
    command_error "Pool/Volname is required" if args.pos_args.size == 0
    args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
    next unless (args.script_mode || yes("Are you sure you want to stop rebalancing of volume? [y/N]"))

    api_call(args, "Failed to stop rebalancing of volume.") do |client|
      volume = client.pool(args.pool_name).volume(volume_name).rebalance_stop

      handle_json_output(volume, args)

      puts "Rebalancing of Volume #{volume.name} stopped"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Stopping of volume rebalance failed"
    STDERR.puts ex
    exit 1
  end
end

command "rebalance.status", "Show Kadalu Storage volume rebalance status" do |parser, args|
  parser.banner = "Usage: kadalu rebalance status POOL/VOLNAME [arguments]"
  parser.on("--detail", "Show detailed rebalance status info of individual storage units") do
    args.rebalance_args.detail = true
  end
end

def rebalance_status_summary(volume, args)
  puts "Name                       : #{volume.pool.name}/#{volume.name}"
  puts "Type                       : #{volume.type}"
  puts "ID                         : #{volume.id}"

  puts "Fix-Layout Status          : #{volume.fix_layout_summary.state}"
  if volume.fix_layout_summary.state != "not started"
    puts "Total Dirs Scanned         : #{volume.fix_layout_summary.total_dirs_scanned}"
    puts "Duration for fixing-layout : #{volume.fix_layout_summary.duration_seconds}"
  end

  printf("Progress                   : %.2f %%\n", volume.migrate_data_summary.avg_of_progress)
  printf("Estimate Seconds           : %i\n", volume.migrate_data_summary.highest_estimate_seconds)
  printf("Scanned                    : %s / %s\n",
    volume.migrate_data_summary.avg_of_scanned_bytes.humanize_bytes, volume.migrate_data_summary.avg_of_total_bytes.humanize_bytes)
  puts

  puts "Volume #{volume.name} Rebalance Status            : #{volume.migrate_data_summary.state}"
  puts "Total Number of Rebalance Process       : #{volume.migrate_data_summary.total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{volume.migrate_data_summary.total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{volume.migrate_data_summary.total_failed_migrate_data_processes}"
end

def detailed_rebalance_status(volume, args)
  puts "Name                                    : #{volume.pool.name}/#{volume.name}"
  puts "Type                                    : #{volume.type}"
  puts "ID                                      : #{volume.id}"

  puts "Fix-Layout Status                       : #{volume.fix_layout_summary.state}"
  if volume.fix_layout_summary.state != "not started"
    puts "Total Dirs Scanned                      : #{volume.fix_layout_summary.total_dirs_scanned}"
    puts "Duration for fixing-layout              : #{volume.fix_layout_summary.duration_seconds}"
  end

  volume.distribute_groups.each_with_index do |dist_grp, dist_grp_index|
    storage_unit = dist_grp.storage_units[0]
    migrate_data_status = storage_unit.migrate_data_status

    printf("Distribute group %-2s\n", dist_grp_index + 1)
    printf(
      "    Storage unit %-3s                    : %s:%s\n",
      1,
      storage_unit.node.name,
      storage_unit.path,
    )

    printf("     Status                             : %s\n", migrate_data_status.state)
    if migrate_data_status.state != "not started"
      printf("     Progress                           : %s %%\n", migrate_data_status.progress)
      printf("     Scanned                            : %s / %s\n", migrate_data_status.scanned_bytes.humanize_bytes, migrate_data_status.total_bytes.humanize_bytes)
      printf("     Duration Seconds                   : %s\n", migrate_data_status.duration_seconds)
      printf("     Estimate Seconds                   : %s\n", migrate_data_status.estimate_seconds)
    end
    puts
  end

  puts "Volume #{volume.name} Rebalance Status            : #{volume.migrate_data_summary.state}"
  puts "Total Number of Rebalance Process       : #{volume.migrate_data_summary.total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{volume.migrate_data_summary.total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{volume.migrate_data_summary.total_failed_migrate_data_processes}"
end

handler "rebalance.status" do |args|
  begin
    command_error "Pool/Volname is required" if args.pos_args.size == 0
    args.pool_name, volume_name = pool_and_volume_name(args.pos_args.size > 0 ? args.pos_args[0] : "")
    api_call(args, "Failed to show rebalance status of volume") do |client|
      volume = client.pool(args.pool_name).volume(volume_name).rebalance_status

      handle_json_output(volume, args)

      if args.rebalance_args.detail
        detailed_rebalance_status(volume, args)
      else
        rebalance_status_summary(volume, args)
      end
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Failed to show rebalance status of Kadalu Storage Volume"
    STDERR.puts ex
    exit 1
  end
end
