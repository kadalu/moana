require "moana_types"

require "./brick_utils"

struct VolumeCreateTask
  property type = "volume_create"
  property parsed : MoanaTypes::Volume

  def initialize
    
  end

  def run(moana_url, cluster_id, node_conf)
    volume = MoanaTypes::Volume.from_json(@data)
    volume.subvols.each do |subvol|
      subvol.bricks.each do |brick|
        # Task execute only for Local Bricks
        next if node_conf.node_id != brick.node.id
        begin
          create_brick(volreq, brick)
        rescue ex: CreateBrickException
          raise TaskException.new("#{ex}", 500)
        end
      end
    end
  end
end
