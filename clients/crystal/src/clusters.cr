module MoanaClient
  class Cluster
    def initialize(@client : Client, @name : String)
    end

    def self.create(client : Client, name : String)
      url = "#{client.url}/api/v1/clusters"

      req = MoanaTypes::ClusterCreateRequest.new
      req.name = name

      response = MoanaClient.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Cluster.from_json(response.body)
      else
        puts response.body
        puts response.status_code
        MoanaClient.error_response(response)
      end
    end
  end
end
