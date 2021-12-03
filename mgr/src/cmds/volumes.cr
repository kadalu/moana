require "./helpers"
require "./volume_create_parser"

struct VolumeArgs
  property status = false, detail = false, name = ""
end

class Args
  property volume_args = VolumeArgs.new
end

def cluster_and_volume_name(value)
  cluster_name, _, volume_name = value.partition("/")
  {cluster_name, volume_name}
end

command "volume.create", "Kadalu Storage Volume Create" do |parser, _|
  parser.banner = "Usage: kadalu volume create CLUSTER/VOLNAME TYPE STORAGE_UNITS [arguments]"
end

handler "volume.create" do |args|
  begin
    req = VolumeRequestParser.parse(args.pos_args)
    args.cluster_name = req.cluster_name
    api_call(args, "Failed to Create Volume") do |client|
      volume = client.cluster(args.cluster_name).create_volume(req)
      puts "Volume #{req.name} created successfully"
      puts "ID: #{volume.id}"
    end
  rescue ex : InvalidVolumeRequest
    STDERR.puts "Volume create failed"
    STDERR.puts ex
    exit 1
  end
end

command "volume.list", "Volumes list of a Kadalu Storage Cluster" do |parser, args|
  parser.banner = "Usage: kadalu volume list CLUSTER [arguments]"
  parser.on("--status", "Show Volumes states") do
    args.volume_args.status = true
  end
  parser.on("--detail", "Show detailed Volumes info") do
    args.volume_args.detail = true
  end
end

def volume_detail(volume, status = false)
  puts "Name                    : #{volume.name}"
  puts "Type                    : #{volume.type}"
  puts "ID                      : #{volume.id}"
  puts "Status                  : #{volume.state}"
  puts "Health                  : #{volume.metrics.health}" if status
  puts "Utilization             : #{volume.metrics.size_used_bytes.humanize_bytes}/#{(volume.metrics.size_used_bytes + volume.metrics.size_free_bytes).humanize_bytes}" if status
  puts "Utilization (Inodes)    : #{volume.metrics.inodes_used_count.humanize}/#{(volume.metrics.inodes_used_count + volume.metrics.inodes_free_count).humanize}" if status
  puts "Number of Storage units : #{volume.distribute_groups.size * volume.distribute_groups[0].storage_units.size}"
  volume.distribute_groups.each_with_index do |dist_grp, grp_idx|
    printf("Distribute Group %-2s%s     :\n", grp_idx + 1, status ? " (#{dist_grp.metrics.health})" : "")
    dist_grp.storage_units.each_with_index do |storage_unit, idx|
      printf(
        "    Storage Unit %-3s    : %s:%s (Port: %s%s)\n",
        idx + 1,
        storage_unit.node_name,
        storage_unit.path,
        storage_unit.port,
        status ? ", Health: #{storage_unit.metrics.health}" : ""
      )
      puts
    end
  end
  puts "Options:" + (volume.options.size > 0 ? "" : " -")

  volume.options.each do |k, v|
    printf("    %20s: %s\n", k, v)
  end
end

handler "volume.list" do |args|
  args.cluster_name, args.volume_args.name = cluster_and_volume_name(args.pos_args.size < 1 ? "" : args.pos_args[0])
  if args.cluster_name == ""
    STDERR.puts "Cluster name is required."
    exit 1
  end

  api_call(args, "Failed to get list of volumes") do |client|
    if args.volume_args.name == ""
      volumes = client.cluster(args.cluster_name).list_volumes(state: args.volume_args.status)
    else
      volumes = [client.cluster(args.cluster_name).volume(args.volume_args.name).get(state: args.volume_args.status)]
    end
    puts "No Volumes available in the Cluster. Run `kadalu volume create #{args.cluster_name}/<volume-name> ...` to create a volume." if volumes.size == 0

    if args.volume_args.detail
      volumes.each do |volume|
        volume_detail(volume, args.volume_args.status)
      end

      next
    end

    # TODO: Include volume.state
    if args.volume_args.status
      printf("%36s  %20s  %10s  %20s  %20s  %s\n", "ID", "Name", "Health", "Type", "Utilization", "Utilization(Inodes)") if volumes.size > 0
    else
      printf("%36s  %20s  %s\n", "ID", "Name", "Type") if volumes.size > 0
    end

    volumes.each do |volume|
      if args.volume_args.status
        printf(
          "%36s  %20s  %10s  %20s  %20s  %s\n", volume.id, volume.name, volume.metrics.health, volume.type,
          "#{volume.metrics.size_used_bytes.humanize_bytes}/#{(volume.metrics.size_used_bytes + volume.metrics.size_free_bytes).humanize_bytes}",
          "#{volume.metrics.inodes_used_count.humanize}/#{(volume.metrics.inodes_used_count + volume.metrics.inodes_free_count).humanize}",
        )
      else
        printf("%36s  %20s  %s\n", volume.id, volume.name, volume.name, volume.type)
      end
    end
  end
end
