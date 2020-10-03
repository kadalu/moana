require "./node_config"

class NodeTaskException < Exception
  property message, status_code

  def initialize(@message : String, @status_code : Int32)
    super(@message)
  end
end

class NodeTask
  def initialize(@moana_url : String, @cluster_id : String, @workdir : String)
  end

  def node_join(node_name, node_endpoint)
    client = MoanaClient::Client.new(@moana_url)
    cluster = client.cluster(@cluster_id)
    node_conf = NodeConfig.new(@moana_url, @workdir, @cluster_id, node_name)

    if node_conf.exists?
      # TODO: Ignore as safe error if Cluster ID is same as already joined
      raise NodeTaskException.new("Node is already part of a Cluster", 400)
    end

    begin
      node = cluster.node_create(node_name, node_endpoint)
      node_conf.save(node)

      node
    rescue ex : MoanaClient::MoanaClientException
      raise NodeTaskException.new("Failed to Join the cluster", ex.status_code)
    end
  end

  def volume_create(node_conf : NodeConfigData, task_data : String)
    volreq = MoanaTypes::VolumeRequest.from_json(task_data)
    volreq.bricks.each do |brick|
      # Task execute only for Local Bricks
      next if node_conf.node_id != brick.node.id

      if brick.device != ""
        brick.mount_path = Path[brick.path].parent.to_s
      end
      begin
        create_brick(volreq, brick)
      rescue ex: CreateBrickException
        raise NodeTaskException.new("#{ex}", 500)
      end
    end
  end

  def volume_start(node_conf : NodeConfigData, task_data : String)
    req = Hash(String, String).from_json(task_data)
    client = MoanaClient::Client.new(node_conf.moana_url)
    volume = client.cluster(node_conf.cluster_id).volume(req["id"])

    begin
      voldata = volume.get
      voldata.subvols.each do |subvol|
        subvol.bricks.each do |brick|
          next if node_conf.node_id != brick.node.id

          if brick.device != ""
            brick.mount_path = Path[brick.path].parent.to_s
          end

          # Download the Volfile
          begin
            volfile = volume.brick_volfile(brick.id)
            filename = "#{@workdir}/volfiles/#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.vol"

            # TODO: Handle file write error
            File.write(filename, volfile.content)
            start_brick(@workdir, voldata, brick)
          rescue ex : MoanaClient::MoanaClientException
            raise NodeTaskException.new("Failed to fetch Volfile", ex.status_code)
          rescue ex : SystemctlException
            raise NodeTaskException.new("#{ex}", 500)
          end
        end
      end
    end
  end

  def volume_stop(node_conf : NodeConfigData, task_data : String)
    req = Hash(String, String).from_json(task_data)
    client = MoanaClient::Client.new(node_conf.moana_url)
    volume = client.cluster(node_conf.cluster_id).volume(req["id"])

    begin
      voldata = volume.get
      voldata.subvols.each do |subvol|
        subvol.bricks.each do |brick|
          next if node_conf.node_id != brick.node.id

          if brick.device != ""
            brick.mount_path = Path[brick.path].parent.to_s
          end

          # Download the Volfile
          begin
            stop_brick(@workdir, voldata, brick)
          rescue ex : SystemctlException
            raise NodeTaskException.new("#{ex}", 500)
          end
        end
      end
    end
  end
end
