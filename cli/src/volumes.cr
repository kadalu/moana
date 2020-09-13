class BrickRequest
  include JSON::Serializable

  property node_id, path, device

  def initialize(@node_id = "", @path = "", @device = "")
  end
end

class VolumeCreateRequest
  include JSON::Serializable

  property name, brick_fs, bricks, xfs_opts, zfs_opts, ext4_opts, replica_count, disperse_count, start

  def initialize(@name = "", @brick_fs = "dir", @bricks = [] of BrickRequest, @xfs_opts = "", @zfs_opts = "", @ext4_opts = "", @replica_count = 1, @disperse_count = 1, @start = false)
  end
end

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

def create_volume(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  req = VolumeCreateRequest.new
  req.name = args.name
  req.brick_fs = args.brick_fs
  req.zfs_opts = args.zfs_opts
  req.xfs_opts = args.xfs_opts
  req.ext4_opts = args.ext4_opts
  req.replica_count = args.replica_count
  req.disperse_count = args.disperse_count
  req.start = args.start
  req.bricks = prepare_bricks_list args, cluster_id, args.bricks

  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/volumes"
  response = HTTP::Client.post(
    url,
    body: req.to_json,
    headers: HTTP::Headers{"Content-Type" => "application/json"}
  )
  if response.status_code == 201
    puts "Volume creation request sent successfully."
    puts "Task ID: #{Task.from_json(response.body).id}"
  else
    STDERR.puts response.status_code
  end
end


def volumes_info(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/volumes"
  response = HTTP::Client.get url
  content = "[]"
  if response.status_code == 200
    content = response.body
  else
    STDERR.puts response.status_code
    exit 1
  end
  volume_data = Array(Volume).from_json(content)
  
  volume_data.each do |vol|
    puts "Name                    : #{vol.name}"
    puts "Type                    : #{vol.type}"
    puts "ID                      : #{vol.id}"
    puts "Status                  : #{vol.state}"
    puts "Number of Storage units : #{vol.bricks.size}"
    vol.bricks.each_with_index do |brick, idx|
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

def show_volumes(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/volumes"
  response = HTTP::Client.get url
  content = "[]"
  if response.status_code == 200
    content = response.body
  else
    STDERR.puts response.status_code
    exit 1
  end
  volume_data = Array(Volume).from_json(content)

  if volume_data
    printf("%-36s  %-15s %-15s %s\n", "ID", "Name", "Type", "State")
  end
  volume_data.each do |volume|
    if args.name == "" || volume.id == args.name || volume.name == args.name
      printf("%-36s  %-15s %-15s %-s\n",volume.id, volume.name, volume.type, volume.state)
    end
  end
end
