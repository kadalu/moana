require "http/client"

require "moana_types"

require "./helpers"

module MoanaClient
  class Volume
    def initialize(@ctx : ClientContext, @cluster_id : String, @id : String)
    end

    def self.create(ctx : ClientContext, req : MoanaTypes::VolumeRequest)
      url = "#{ctx.url}/api/clusters/#{req.cluster_id}/volumes"
      response = HTTP::Client.post(
        url,
        body: req.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 201
        MoanaTypes::TaskResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    private def action(name)
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/volumes/#{@id}/#{name}"
      response = HTTP::Client.post url

      if response.status_code == 200
        MoanaTypes::TaskResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def start
      action("start")
    end

    def stop
      action("stop")
    end

    def get
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/volumes/#{@id}"
      response = HTTP::Client.get url
      if response.status_code == 200
        MoanaTypes::VolumeResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String)
      url = "#{ctx.url}/api/clusters/#{cluster_id}/volumes"
      response = HTTP::Client.get url
      if response.status_code == 200
        Array(MoanaTypes::VolumeResponse).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/volumes/#{@id}"
      response = HTTP::Client.delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def brick_volfile(brick_id : String)
      url = "#{@ctx.url}/api/volfiles/#{@cluster_id}/brick/#{@id}/#{brick_id}"
      response = HTTP::Client.get url

      if response.status_code == 200
        MoanaTypes::VolfileResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
