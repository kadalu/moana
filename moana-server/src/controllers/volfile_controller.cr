require "../volgen"
require "../default_volfiles"

class VolfileController < ApplicationController
  def show_cluster_level
      results = {status: "not implemented"}
      respond_with 500 do
        json results.to_json
      end
  end

  def show_volume_and_brick_level
    voldata = VolumeView.all("WHERE volumes.id = ?", [params["volume_id"]])
    if voldata.size > 0
      volume = VolumeView.response(voldata)

      volfile_content =
        if params["brick_id"]?
          # TODO: Get Volfile template from Db based on params["name"]
          Volfile.brick_level(params["name"], BRICK_VOLFILE, volume[0], params["brick_id"])
        else
          # TODO: Get Volfile template from Db based on params["name"]
          Volfile.volume_level(params["name"], CLIENT_VOLFILE, volume[0])
        end

      if volfile_content == ""
        results = {status: "failed to get volfile content"}
        respond_with 500 do
          json results.to_json
        end
      else
        result = {"content" => volfile_content}
        respond_with 200 do
          json result.to_json
        end
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

end
