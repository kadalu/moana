require "uuid"

require "moana_types"

DISTRIBUTE = "Distribute"
REPLICATE = "Replicate"
DISPERSE = "Disperse"
DISTRIBUTED_REPLICATE = "Distribute Replicate"
DISTRIBUTED_DISPERSE = "Distribute Disperse"


def volume_from_request(req : MoanaTypes::VolumeCreateRequest)
  volume = MoanaTypes::Volume.new
  volume.id = UUID.random.to_s
  volume.name = req.name
  volume.replica_count = req.replica_count
  volume.disperse_count = req.disperse_count
  volume.brick_fs = req.brick_fs
  volume.fs_opts = req.fs_opts

  subvol_type = DISTRIBUTE
  subvol_type = REPLICATE if req.replica_count > 1
  subvol_type = DISPERSE if req.disperse_count > 1

  subvol_bricks_count = req.replica_count > 1 ? req.replica_count : req.disperse_count
  number_of_subvols = req.bricks.size / subvol_bricks_count

  volume.type = subvol_type
  volume.type = "#{DISTRIBUTE} #{subvol_type}" if number_of_subvols > 1

  volume.subvols = (0 .. number_of_subvols-1).map do |sidx|
    subvol = MoanaTypes::Subvol.new

    subvol.replica_count = req.replica_count
    subvol.disperse_count = req.disperse_count
    subvol.type = subvol_type
    subvol.bricks = (0 .. subvol_bricks_count-1).map do |bidx|
      brickreq = req.bricks[sidx * subvol_bricks_count + bidx]
      brick = MoanaTypes::Brick.new
      brick.id = UUID.random.to_s
      brick.node.id = brickreq.node_id
      brick.path = brickreq.path
      brick.device = brickreq.device

      brick
    end

    subvol
  end

  volume
end
