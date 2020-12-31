require "http/client"

require "moana_types"

require "./helpers"

module MoanaClient
  class Volume
    def initialize(@ctx : ClientContext, @cluster_id : String, @id : String)
    end

    def self.create(ctx : ClientContext, req : MoanaTypes::VolumeCreateRequest)
      url = "#{ctx.url}/api/v1/clusters/#{req.cluster_id}/volumes"
      response = MoanaClient.http_post(
        url,
        req.to_json
      )
      if response.status_code == 201
        MoanaTypes::Task.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    private def action(name)
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/volumes/#{@id}/#{name}"
      response = MoanaClient.http_post url, "{}"

      if response.status_code == 200
        MoanaTypes::Task.from_json(response.body)
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
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/volumes/#{@id}"
      response = MoanaClient.http_get url
      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String)
      url = "#{ctx.url}/api/v1/clusters/#{cluster_id}/volumes"
      response = MoanaClient.http_get url
      if response.status_code == 200
        Array(MoanaTypes::Volume).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/volumes/#{@id}"
      response = MoanaClient.http_delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def brick_volfile(brick_id : String)
      url = "#{@ctx.url}/api/v1/volfiles/#{@cluster_id}/brick/#{@id}/#{brick_id}"
      response = MoanaClient.http_get url

      if response.status_code == 200
        MoanaTypes::Volfile.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def setopt(req : Hash(String, String))
      url = "#{ctx.url}/api/v1/clusters/#{req.cluster_id}/volumes/#{@id}/options/set"
      response = MoanaClient.http_post(
        url,
        req.to_json
      )
      if response.status_code == 200
        MoanaTypes::Task.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def resetopt(req : Array(String))
      url = "#{ctx.url}/api/v1/clusters/#{req.cluster_id}/volumes/#{@id}/options/reset"
      response = MoanaClient.http_post(
        url,
        req.to_json
      )
      if response.status_code == 200
        MoanaTypes::Task.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
