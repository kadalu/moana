module StorageManager
  class Node
    def initialize(@client : Client, @pool_name : String, @name : String)
    end

    def self.add(client : Client, pool_name : String, name : String, endpoint : String)
      url = "#{client.url}/api/v1/pools/#{pool_name}/nodes"

      req = MoanaTypes::NodeRequest.new
      req.name = name
      req.endpoint = endpoint

      response = StorageManager.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Node.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, pool_name : String, state = false)
      url = "#{client.url}/api/v1/pools/#{pool_name}/nodes?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Node).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, state = false)
      url = "#{client.url}/api/v1/nodes?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Node).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/nodes/#{@name}"

      response = StorageManager.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        StorageManager.error_response(response)
      end
    end
  end
end
