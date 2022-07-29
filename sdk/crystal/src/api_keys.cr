module StorageManager
  class ApiKey
    def initialize(@client : Client, @api_key_id : String)
    end

    def self.create(client : Client, name : String)
      url = "#{client.url}/api/v1/api-keys"

      req = {"name": name}
      response = StorageManager.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::ApiKey.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, user_id : String)
      url = "#{client.url}/api/v1/api-keys"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::ApiKey).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/api-keys/#{@api_key_id}"

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
