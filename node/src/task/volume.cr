require "moana_types"

require "./brick_utils"
require "./task"

struct VolumeCreateTask < Task
  property type = "volume_create"
  @parsed : MoanaTypes::Volume | Nil = nil

  def parsed
    if @parsed.nil?
      @parsed = MoanaTypes::Volume.from_json(@data)
    end

    @parsed.not_nil!
  end

  def initialize
  end

  def run(node_conf)
    parsed.subvols.each do |subvol|
      subvol.bricks.each do |brick|
        # Task execute only for Local Bricks
        next if node_conf.node_id != brick.node.id
        begin
          create_brick(parsed, brick)
        rescue ex: CreateBrickException
          raise TaskException.new("#{ex}", 500)
        end
      end
    end
  end
end

struct VolumeStartTask < Task
  property type = "volume_start"
  @parsed : MoanaTypes::Volume | Nil = nil

  def parsed
    if @parsed.nil?
      @parsed = MoanaTypes::Volume.from_json(@data)
    end

    @parsed.not_nil!
  end

  def initialize
  end

  def run(node_conf)
    client = MoanaClient::Client.new(node_conf.moana_url, "", node_conf.token, node_conf.node_id)
    volume_client = client.cluster(node_conf.cluster_id).volume(parsed.id)

    parsed.subvols.each do |subvol|
      subvol.bricks.each do |brick|
        # Task execute only for Local Bricks
        next if node_conf.node_id != brick.node.id

        # Download the Volfile
        begin
          volfile = volume_client.brick_volfile(brick.id, "brick")
          filename = "#{node_conf.workdir}/volfiles/#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.vol"

          # TODO: Handle file write error
          File.write(filename, volfile.content)
          start_brick(node_conf.workdir, parsed, brick)
        rescue ex : MoanaClient::MoanaClientException
          raise TaskException.new("Failed to fetch Volfile", ex.status_code)
        rescue ex : SystemctlException
          raise TaskException.new("#{ex}", 500)
        end
      end
    end
  end
end

struct VolumeStopTask < Task
  property type = "volume_stop"
  @parsed : MoanaTypes::Volume | Nil = nil

  def parsed
    if @parsed.nil?
      @parsed = MoanaTypes::Volume.from_json(@data)
    end

    @parsed.not_nil!
  end

  def initialize
  end

  def run(node_conf)
    parsed.subvols.each do |subvol|
      subvol.bricks.each do |brick|
        # Task execute only for Local Bricks
        next if node_conf.node_id != brick.node.id

        begin
          stop_brick(node_conf.workdir, parsed, brick)
        rescue ex : SystemctlException
          raise TaskException.new("#{ex}", 500)
        end
      end
    end
  end
end
