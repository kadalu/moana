require "../brickutils"

class NodeRequest
  include JSON::Serializable

  property id : String, hostname : String, endpoint : String
end

class BrickRequest
  include JSON::Serializable

  property id : String = "", path : String, device : String, node : NodeRequest, mount_path : String = "", port : Int32 = 0
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

class SubvolRequest
  include JSON::Serializable

  property name : String,
           bricks : Array(BrickRequest)
end

class VolumeSubvolRequest
  include JSON::Serializable

  property id : String,
           name : String,
           subvols : Array(SubvolRequest),
           brick_fs : String,
           xfs_opts : String = "",
           zfs_opts : String = "",
           ext4_opts : String = ""
end

struct Volfile
  include JSON::Serializable

  property content : String
end

def nodedata_from_conf
  workdir = ENV.fetch("WORKDIR", "")
  filename = "#{workdir}/#{ENV["NODENAME"]}.json"
  if File.exists?(filename)
    NodeConfig.from_json(File.read(filename))
  else
    nil
  end
end

class VolumeController < ApplicationController
  def create
    this_node = nodedata_from_conf
    if this_node.nil?
      result = {error: "failed to get node configuration"}
      return respond_with 500 do
        json result.to_json
      end
    end

    volreq = VolumeRequest.from_json(params["data"])
    volreq.bricks.each do |brick|
      next if this_node.node_id != brick.node.id

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

  def start
    this_node = nodedata_from_conf
    if this_node.nil?
      result = {error: "failed to get node configuration"}
      return respond_with 500 do
        json result.to_json
      end
    end

    volreq = VolumeSubvolRequest.from_json(params["data"])
    volreq.subvols.each do |subvol|
      subvol.bricks.each do |brick|
        next if this_node.node_id != brick.node.id

        if brick.device != ""
          brick.mount_path = Path[brick.path].parent.to_s
        end

        # Download the Volfile
        url = "#{this_node.moana_url}/api/volfiles/#{params["cluster_id"]}/brick/#{volreq.id}/#{brick.id}"
        response = HTTP::Client.get url
        content = "[]"
        workdir = ENV.fetch("WORKDIR", "")

        # Download and Create the Volfile
        if response.status_code == 200
          volfile = Volfile.from_json(response.body)

          filename = "#{workdir}/volfiles/#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.vol"
          File.write(filename, volfile.content)
        else
          result = {error: "Failed to fetch Volfile: #{response.status_code}"}
          return respond_with 500 do
            json result.to_json
          end
        end

        # Create the config file
        filename = "#{workdir}/#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.json"
        File.write(filename, {
                     "path" => brick.path,
                     "node.id" => brick.node.id,
                     "node.hostname" => brick.node.hostname,
                     "volume.name" => volreq.name,
                     "port" => brick.port,
                     "device" => brick.device
                   }.to_json)

        # Enable the Service
        ret, resp = execute(
               "systemctl", [
                 "enable",
                 "kadalu-brick@#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.service"
               ])
        if ret != 0
          result = {error: "Failed to enable service: #{resp}"}
          return respond_with 500 do
            json result.to_json
          end
        end

        # Start the Service
        ret, resp = execute(
               "systemctl", [
                 "start",
                 "kadalu-brick@#{brick.node.hostname}:#{brick.path.gsub("/", "-")}.service"
               ])
        if ret != 0
          result = {error: "Failed to start service: #{resp}"}
          return respond_with 500 do
            json result.to_json
          end
        end
      end
    end
    respond_with 201 do
      json "{\"ok\": true}"
    end
  end
end
