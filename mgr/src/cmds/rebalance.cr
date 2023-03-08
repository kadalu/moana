require "./helpers"

struct RebalanceArgs
  property detail = false
end

class Args
  property rebalance_args = RebalanceArgs.new
end

command "rebalance.start", "Start Rebalancing Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu rebalance start POOL [arguments]"
end

handler "rebalance.start" do |args|
  begin
    command_error "Pool is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
    api_call(args, "Failed to start rebalancing of pool") do |client|
      pool = client.pool(pool_name).rebalance_start

      handle_json_output(pool, args)

      puts "Rebalance of Pool #{pool.name} started"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Starting of pool rebalance failed"
    STDERR.puts ex
    exit 1
  end
end

command "rebalance.stop", "Stop Rebalancing Kadalu Storage pool" do |parser, _|
  parser.banner = "Usage: kadalu rebalance stop POOL [arguments]"
end

handler "rebalance.stop" do |args|
  begin
    command_error "Pool/Volname is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
    next unless (args.script_mode || yes("Are you sure you want to stop rebalancing of the pool? [y/N]"))

    api_call(args, "Failed to stop rebalancing of pool.") do |client|
      pool = client.pool(pool_name).rebalance_stop

      handle_json_output(pool, args)

      puts "Rebalancing of Pool #{pool.name} stopped"
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Stopping of pool rebalance failed"
    STDERR.puts ex
    exit 1
  end
end

command "rebalance.status", "Show Kadalu Storage pool rebalance status" do |parser, args|
  parser.banner = "Usage: kadalu rebalance status POOL [arguments]"
  parser.on("--detail", "Show detailed rebalance status info of individual storage units") do
    args.rebalance_args.detail = true
  end
end

def rebalance_status_summary(pool, args)
  puts "Name                       : #{pool.name}"
  puts "Type                       : #{pool.type}"
  puts "ID                         : #{pool.id}"

  puts "Fix-Layout Status          : #{pool.fix_layout_summary.state}"
  if pool.fix_layout_summary.state != "not started"
    puts "Total Dirs Scanned         : #{pool.fix_layout_summary.total_dirs_scanned}"
    puts "Duration for fixing-layout : #{pool.fix_layout_summary.duration_seconds}"
  end

  printf("Progress                   : %.2f %%\n", pool.migrate_data_summary.avg_of_progress)
  printf("Estimate Seconds           : %i\n", pool.migrate_data_summary.highest_estimate_seconds)
  printf("Scanned                    : %s / %s\n",
    pool.migrate_data_summary.avg_of_scanned_bytes.humanize_bytes, pool.migrate_data_summary.avg_of_total_bytes.humanize_bytes)
  puts

  puts "Pool #{pool.name} Rebalance Status            : #{pool.migrate_data_summary.state}"
  puts "Total Number of Rebalance Process       : #{pool.migrate_data_summary.total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{pool.migrate_data_summary.total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{pool.migrate_data_summary.total_failed_migrate_data_processes}"
end

def detailed_rebalance_status(pool, args)
  puts "Name                                    : #{pool.name}"
  puts "Type                                    : #{pool.type}"
  puts "ID                                      : #{pool.id}"

  puts "Fix-Layout Status                       : #{pool.fix_layout_summary.state}"
  if pool.fix_layout_summary.state != "not started"
    puts "Total Dirs Scanned                      : #{pool.fix_layout_summary.total_dirs_scanned}"
    puts "Duration for fixing-layout              : #{pool.fix_layout_summary.duration_seconds}"
  end

  pool.distribute_groups.each_with_index do |dist_grp, dist_grp_index|
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

  puts "Pool #{pool.name} Rebalance Status            : #{pool.migrate_data_summary.state}"
  puts "Total Number of Rebalance Process       : #{pool.migrate_data_summary.total_migrate_data_processes}"
  puts "Number of Completed Rebalance Process   : #{pool.migrate_data_summary.total_completed_migrate_data_processes}"
  puts "Number of Failed Rebalance Process      : #{pool.migrate_data_summary.total_failed_migrate_data_processes}"
end

handler "rebalance.status" do |args|
  begin
    command_error "Pool is required" if args.pos_args.size == 0
    pool_name = args.pos_args.size > 0 ? args.pos_args[0] : ""
    api_call(args, "Failed to show rebalance status of the pool") do |client|
      pool = client.pool(pool_name).rebalance_status

      handle_json_output(pool, args)

      if args.rebalance_args.detail
        detailed_rebalance_status(pool, args)
      else
        rebalance_status_summary(pool, args)
      end
    end
  rescue ex : InvalidPoolRequest
    STDERR.puts "Failed to show rebalance status of Kadalu Storage Pool"
    STDERR.puts ex
    exit 1
  end
end
