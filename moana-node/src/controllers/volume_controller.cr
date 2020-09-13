require "../brickutils"

class NodeRequest
  include JSON::Serializable

  property id : String, hostname : String, endpoint : String
end

class BrickRequest
  include JSON::Serializable

  property path : String, device : String, node : NodeRequest, mount_path : String = ""
end

class VolumeRequest
  include JSON::Serializable

  property id : String,
           name : String,
           bricks : Array(BrickRequest),
           brick_fs : String,
           xfs_opts : String = "",
           zfs_opts : String = "",
           ext4_opts : String = ""
end

class VolumeController < ApplicationController
  def create
    volreq = VolumeRequest.from_json(params["data"])
    volreq.bricks.each do |brick|
      next if ENV.fetch("NODE_ID", "") != brick.node.id

      if brick.device != ""
        brick.mount_path = Path[brick.path].parent.to_s
      end
      begin
        create_brick(volreq, brick)
      rescue ex: CreateBrickException
        result = {error: "#{ex}"}
        return respond_with 500 do
          json result.to_json
        end
      end
    end

    respond_with 201 do
      json "{\"ok\": true}"
    end
  end
end
