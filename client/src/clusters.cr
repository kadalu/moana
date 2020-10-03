require "http/client"

require "moana_types"

require "./helpers"
require "./volumes"
require "./nodes"

module MoanaClient
  class Cluster
    def initialize(@ctx : ClientContext, @cluster_id : String)
    end

    def self.create(ctx : ClientContext, name : String)
      response = HTTP::Client.post(
        "#{ctx.url}/api/clusters",
        body: {name: name}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 201
        MoanaTypes::ClusterResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def info
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}"
      response = HTTP::Client.get url
      if response.status_code == 200
        MoanaTypes::ClusterResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext)
      url = "#{ctx.url}/api/clusters"
      response = HTTP::Client.get url
      if response.status_code == 200
        Array(MoanaTypes::ClusterResponse).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def update(name)
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}"
      response = HTTP::Client.put(
        url,
        body: {name: name}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )

      if response.status_code == 200
        MoanaTypes::ClusterResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}"
      response = HTTP::Client.delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def volume_create(req)
      Volume.create(@ctx, req)
    end

    def volume(id : String)
      Volume.new(@ctx, @cluster_id, id)
    end

    def volumes()
      Volume.all(@ctx, @cluster_id)
    end

    def node_create(endpoint : String, token : String)
      Node.create(@ctx, @cluster_id, endpoint, token)
    end

    def node(id : String)
      Node.new(@ctx, @cluster_id, id)
    end

    def nodes()
      Node.all(@ctx, @cluster_id)
    end
  end
end
