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
  total_migrate_data_processes = 0
  total_non_started_migrate_data_processes = 0
  total_completed_migrate_data_processes = 0
  total_failed_migrate_data_processes = 0
  rebalance_status = ""
  highest_estimate_seconds = -2147483648
  sum_of_scanned_bytes = 0
  sum_of_total_bytes = 0
  sum_of_progress = 0
  fix_layout_status = volume.distribute_groups[0].storage_units[0].fix_layout_status

  puts "Name                       : #{volume.pool.name}/#{volume.name}"
  puts "Type                       : #{volume.type}"
  puts "ID                         : #{volume.id}"

  puts "Fix-Layout Status          : #{fix_layout_status.state}"
  if fix_layout_status.state != "not started"
    puts "Total Dirs Scanned         : #{fix_layout_status.total_dirs}"
    puts "Duration                   : #{fix_layout_status.duration_seconds}"
  end

  volume.distribute_groups.each do |dist_grp|
    storage_unit = dist_grp.storage_units[0]
    migrate_data_status = storage_unit.migrate_data_status
    total_migrate_data_processes += 1

    case migrate_data_status.state
    when "not started"
      total_non_started_migrate_data_processes += 1
    when "complete"
      total_completed_migrate_data_processes += 1
    when "failed"
      total_failed_migrate_data_processes += 1
    end

    if migrate_data_status.estimate_seconds.to_i64 > highest_estimate_seconds
      highest_estimate_seconds = migrate_data_status.estimate_seconds.to_i64
    end

    sum_of_scanned_bytes += migrate_data_status.scanned_bytes.to_i64
    sum_of_total_bytes += migrate_data_status.total_bytes.to_i64
    sum_of_progress += migrate_data_status.progress.to_i64
  end

  printf("Progress                   : %.2f %%\n", (sum_of_progress/total_migrate_data_processes))
  printf("Estimate Seconds           : %i\n", highest_estimate_seconds)
  printf("Scanned                    : %s / %s\n",
    (sum_of_scanned_bytes/total_migrate_data_processes).to_i64.humanize_bytes, (sum_of_total_bytes/total_migrate_data_processes).to_i64.humanize_bytes)
  puts

  if total_completed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "complete"
  elsif total_failed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "fail"
  elsif total_non_started_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "not started"
  else
    rebalance_status = "partial"
  end

  puts "Volume #{volume.name} Rebalance Status            : #{rebalance_status}"
  puts "Total Number of Rebalance Process       : #{total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{total_failed_migrate_data_processes}"
end

def detailed_rebalance_status(volume, args)
  total_migrate_data_processes = 0
  total_completed_migrate_data_processes = 0
  total_non_started_migrate_data_processes = 0
  total_failed_migrate_data_processes = 0
  fix_layout_status = volume.distribute_groups[0].storage_units[0].fix_layout_status
  rebalance_status = ""

  puts "Name                                    : #{volume.pool.name}/#{volume.name}"
  puts "Type                                    : #{volume.type}"
  puts "ID                                      : #{volume.id}"

  puts "Fix-Layout Status                       : #{fix_layout_status.state}"
  if fix_layout_status.state != "not started"
    puts "Total Dirs Scanned                      : #{fix_layout_status.total_dirs}"
    puts "Duration                                : #{fix_layout_status.duration_seconds}"
  end
  puts

  volume.distribute_groups.each_with_index do |dist_grp, dist_grp_index|
    storage_unit = dist_grp.storage_units[0]
    migrate_data_status = storage_unit.migrate_data_status

    total_migrate_data_processes += 1

    case migrate_data_status.state
    when "not started"
      total_non_started_migrate_data_processes += 1
    when "complete"
      total_completed_migrate_data_processes += 1
    when "failed"
      total_failed_migrate_data_processes += 1
    end

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

  if total_completed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "complete"
  elsif total_failed_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "fail"
  elsif total_non_started_migrate_data_processes == total_migrate_data_processes
    rebalance_status = "not started"
  else
    rebalance_status = "partial"
  end

  puts "Volume #{volume.name} Rebalance Status            : #{rebalance_status}"
  puts "Total Number of Rebalance Process       : #{total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{total_failed_migrate_data_processes}"
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