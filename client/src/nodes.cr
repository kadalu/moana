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
      url = "#{ctx.url}/api/clusters/#{cluster_id}/nodes"
      response = HTTP::Client.post(
        url,
        body: {hostname: hostname, endpoint: endpoint}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 201
        MoanaTypes::NodeResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.join(ctx : ClientContext, cluster_id : String, endpoint : String, token : String)
      # Connect to node endpoint and ask to Join
      url = "#{endpoint}/api/join"
      response = HTTP::Client.post(
        url,
        body: {cluster_id: cluster_id, moana_url: ctx.url, token: token}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 201
        MoanaTypes::NodeResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def get
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/nodes/#{@id}"
      response = HTTP::Client.get url
      if response.status_code == 200
        MoanaTypes::NodeResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String)
      url = "#{ctx.url}/api/clusters/#{cluster_id}/nodes"
      response = HTTP::Client.get url
      if response.status_code == 200
        Array(MoanaTypes::NodeResponse).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def update(newname : String, endpoint : String)
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/nodes/#{@id}"
      response = HTTP::Client.put(
        url,
        body: {hostname: newname, endpoint: endpoint}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 200
        MoanaTypes::NodeResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/nodes/#{@id}"
      response = HTTP::Client.delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def tasks
      Task.all(@ctx, @cluster_id, @id)
    end
  end
end
