require "http/client"

require "moana_types"

require "./helpers"

module MoanaClient
  class Task
    def initialize(@ctx : ClientContext, @cluster_id : String, @id : String)
    end

    def get
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/tasks/#{@id}"
      response = HTTP::Client.get url
      if response.status_code == 200
        MoanaTypes::TaskResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String)
      url = "#{ctx.url}/api/clusters/#{cluster_id}/tasks"
      response = HTTP::Client.get url
      if response.status_code == 200
        Array(MoanaTypes::TaskResponse).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext, cluster_id : String, node_id : String)
      url = "#{ctx.url}/api/tasks/#{cluster_id}/#{node_id}"
      response = HTTP::Client.get url
      if response.status_code == 200
        Array(MoanaTypes::TaskResponse).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def update(state : String, response : String)
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/tasks/#{@id}"
      response = HTTP::Client.put(
        url,
        body: {state: state, response: response}.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
      if response.status_code == 200
        MoanaTypes::TaskResponse.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/clusters/#{@cluster_id}/tasks/#{@id}"
      response = HTTP::Client.delete url

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end
end
