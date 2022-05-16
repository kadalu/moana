require "./helpers"
require "../server/datastore/*"
require "file_utils"
require "./cli_table"

struct ConfigSnapshotArgs
  property snaps_dir = "", overwrite = false, from_dir = ""
end

class Args
  property config_snapshot_args = ConfigSnapshotArgs.new
end

command "config-snapshot.create", "Take Snapshot of Kadalu Storage Configurations" do |parser, args|
  parser.banner = "Usage: kadalu config-snapshot create [arguments]"
  parser.on("--overwrite", "Replace the existing Snapshot with the new one.") do
    args.config_snapshot_args.overwrite = true
  end
end

handler "config-snapshot.create" do |args|
  if args.pos_args.size == 0
    STDERR.puts "Snapshot name cannot be empty"
    exit 1
  end

  snap_name = args.pos_args[0]

  api_call(args, "Failed to set the backup dir") do |client|
    response = client.create_config_snapshot(
      snap_name,
      args.config_snapshot_args.overwrite
    )

    handle_json_output(response, args)
    puts <<-STRING
    Snapshot #{snap_name} created Successfully! Upload or copy the files from
    `/var/lib/kadalu/config-snapshots/#{snap_name}` directory from the Manager node
    to the cloud or any other machines. To restore or recreate the Manager
    node, then download the backup copy from the cloud and run the restore
    command as below.

    kadalu config-snapshot restore #{snap_name}
    STRING
  end
end

command "config-snapshot.restore", "Restore Kadalu Storage Configurations by specifying the Snapshot name" do |parser, args|
  parser.banner = "Usage: kadalu config-snapshot restore [arguments]"
  parser.on("--from-dir=DIR", "Kadalu Snapshots root directory") do |snaps_dir|
    args.config_snapshot_args.snaps_dir = snaps_dir
  end
end

handler "config-snapshot.restore" do |args|
  if args.pos_args.size == 0
    STDERR.puts "Snapshot name cannot be empty"
    exit 1
  end

  snap_name = args.pos_args[0]
  workdir = "/var/lib/kadalu"

  if File.exists?("#{workdir}/meta/kadalu.db")
    next unless (args.script_mode || yes("Are you sure you want to overwrite Kadalu metadata?"))
  end

  snaps_root = "#{workdir}/config-snapshots"
  if args.config_snapshot_args.from_dir != ""
    snaps_root = args.config_snapshot_args.from_dir
  end

  snap_dir = "#{snaps_root}/#{snap_name}"

  if !Dir.exists?(snap_dir)
    error_message = "Snapshots directory #{snap_dir} does not exist"
    handle_json_error(error_message, args)
    command_error(error_message)
  end

  FileUtils.touch("#{workdir}/mgr")

  Dir.mkdir_p "#{workdir}/meta"

  FileUtils.cp("#{snap_dir}/info", "#{workdir}/info")

  Datastore.dump("#{snap_dir}/kadalu_snapshot.db", "#{workdir}/meta/kadalu.db")

  handle_json_output(nil, args)
  puts <<-STRING
  Kadalu Storage setup restored from the Snapshot #{snap_name} successfully!.
  Start the kadalu mgr process as below.

  kadalu mgr
  STRING
end

command "config-snapshot.list", "Kadalu Storage Config Snapshots List" do |parser, _args|
  parser.banner = "Usage: kadalu config-snapshot list [arguments]"
end

handler "config-snapshot.list" do |args|
  api_call(args, "Failed to get the list of Config Snapshots") do |client|
    snaps = client.list_config_snapshots

    handle_json_output(snaps, args)

    puts "No Snapshots. Run `kadalu config-snapshot create <name>` to create a Snapshot." if snaps.size == 0

    table = CliTable.new(2)
    table.header("Name", "Created On")
    snaps.each do |snap|
      table.record(snap.name, snap.created_on)
    end

    table.render
  end
end

command "config-snapshot.delete", "Delete the Kadalu Storage Config Snapshot" do |parser, _|
  parser.banner = "Usage: kadalu config-snapshot delete SNAP [arguments]"
end

handler "config-snapshot.delete" do |args|
  command_error "Snapshot name is required" if args.pos_args.size < 1

  next unless (args.script_mode || yes("Are you sure you want to delete the Config Snapshot?"))

  api_call(args, "Failed to Delete the Snapshot") do |client|
    client.config_snapshot(args.pos_args[0]).delete
    handle_json_output(nil, args)
    puts "Config Snapshot #{args.pos_args[0]} deleted"
  end
end
