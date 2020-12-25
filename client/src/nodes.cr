require "http/client"

require "moana_types"

require "./helpers"
require "./tasks"

module MoanaClient
  class Node
    def initialize(@ctx : ClientContext, @cluster_id : String, @id : String)
    end

    def self.create(ctx : ClientContext, cluster_id : String, hostname : String, endpoint : String)
      # Cluster_id and Token
      url = "#{ctx.url}/api/v1/clusters/#{cluster_id}/nodes"
      response = http_post(
        url,
        {hostname: hostname, endpoint: endpoint}.to_json
      )
      if response.status_code == 201
        MoanaTypes::Node.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.join(ctx : ClientContext, cluster_id : String, endpoint : String, token : String)
      # Connect to node endpoint and ask to Join
      url = "#{endpoint}/api/v1/join"
      response = http_post(
        url,
        {cluster_id: cluster_id, moana_url: ctx.url, token: token}.to_json
      )
      if response.status_code == 201
        MoanaTypes::Node.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def get
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/nodes/#{@id}"
      response = http_get url
      if response.status_code == 200
        MoanaTypes::Node.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String)
      url = "#{ctx.url}/api/v1/clusters/#{cluster_id}/nodes"
      response = http_get url
      if response.status_code == 200
        Array(MoanaTypes::Node).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def update(newname : String, endpoint : String)
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/nodes/#{@id}"
      response = http_put(
        url,
        {hostname: newname, endpoint: endpoint}.to_json
      )
      if response.status_code == 200
        MoanaTypes::Node.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/nodes/#{@id}"
      response = http_delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def tasks
      Task.all(@ctx, @cluster_id, @id)
    end
  end
end
