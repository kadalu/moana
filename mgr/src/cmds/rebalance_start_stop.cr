require "./helpers"

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
