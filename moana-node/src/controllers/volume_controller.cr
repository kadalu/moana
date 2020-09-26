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

def nodeid_from_conf
  workdir = ENV.fetch("WORKDIR", "")
  filename = "#{workdir}/#{ENV["NODENAME"]}.json"
  nodeid = ""
  if File.exists?(filename)
    conf = NodeConfig.from_json(File.read(filename))
    if tmp = conf.node_id
      nodeid = tmp
    end
  end

  nodeid
end

class VolumeController < ApplicationController
  def create
    this_node = nodeid_from_conf
    volreq = VolumeRequest.from_json(params["data"])
    volreq.bricks.each do |brick|
      next if this_node != brick.node.id

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
