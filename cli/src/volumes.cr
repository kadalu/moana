require "moana_types"

include MoanaTypes

def prepare_bricks_list(args, cluster_id, data)
  if nodes = nodes_by_cluster_id(cluster_id)
    nodedata = {} of String => String
    nodes.each do |node|
      nodedata[node.hostname] = node.id
    end

    bricks = [] of BrickRequest
    data.each do |item|
      node_hostname, brick_path = item.split(":")
      node_id = nodedata.fetch(node_hostname, nil)
      if node_id.nil?
        STDERR.puts "Invalid node #{node_hostname}"
        exit 1
      end
      brick = BrickRequest.new node_id: node_id

      if args.brick_fs == "dir"
        brick.path = brick_path
      else
        brick.device = brick_path
      end
      bricks << brick
    end

    bricks
  else
    STDERR.puts "Invalid Cluster ID or name"
    exit 1
  end

end

def volume_id_from_name(client, cluster_id, name)
  begin
    # TODO: Optimize this by calling search API
    # Now this is getting all volumes and searching
    volumes = client.cluster(cluster_id).volumes
    volumes.each do |volume|
      if volume.name == name || volume.id == name
        return volume.id
      end
    end

    STDERR.puts "Invalid Volume name"
    exit 1
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts "Failed to get Volume ID from the name(HTTP Error: #{ex.status_code})"
    exit 1
  end
end

def start_stop_volume(gflags, args, action)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)

  begin
    volume_id = volume_id_from_name(client, cluster_id, args.name)
    volume = client.cluster(cluster_id).volume(volume_id)
    task = if action == "start"
             volume.start
           else
             volume.stop
           end
      puts "Volume #{action} request sent successfully."
      puts "Task ID: #{task.id}"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end

def create_volume(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  req = VolumeRequest.new
  req.name = args.name
  req.brick_fs = args.brick_fs
  req.zfs_opts = args.zfs_opts
  req.xfs_opts = args.xfs_opts
  req.ext4_opts = args.ext4_opts
  req.replica_count = args.replica_count
  req.disperse_count = args.disperse_count
  req.start = args.start
  req.bricks = prepare_bricks_list args, cluster_id, args.bricks
  req.cluster_id = cluster_id

  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    task = cluster.volume_create(req)
    puts "Volume creation request sent successfully."
    puts "Task ID: #{task.id}"
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
  end
end

def volumes_info(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    volume_data = cluster.volumes
    volume_data.each do |vol|
      puts "Name                    : #{vol.name}"
      puts "Type                    : #{vol.type}"
      puts "ID                      : #{vol.id}"
      puts "Status                  : #{vol.state}"
      puts "Number of Storage units : #{vol.subvols.size * vol.subvols[0].bricks.size}"
      vol.subvols.each_with_index do |subvol, sidx|
        subvol.bricks.each_with_index do |brick, idx|
          printf(
            "Storage Unit %-3s        : %s:%s (Port: %s)\n",
            idx+1,
            brick.node.hostname,
            brick.path,
            brick.port
          )
          puts
          puts
        end
      end
    end
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end

def show_volumes(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    volume_data = cluster.volumes
    if volume_data
      printf("%-36s  %-15s %-15s %s\n", "ID", "Name", "Type", "State")
    end
    volume_data.each do |volume|
      if args.name == "" || volume.id == args.name || volume.name == args.name
        printf("%-36s  %-15s %-15s %-s\n",volume.id, volume.name, volume.type, volume.state)
      end
    end
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end
