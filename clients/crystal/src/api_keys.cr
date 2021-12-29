module MoanaClient
  class ApiKey
    def initialize(@client : Client, @api_key_id : String)
    end

    def self.create(client : Client, name : String)
      url = "#{client.url}/api/v1/api-keys"

      req = {"name": name}
      response = MoanaClient.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::ApiKey.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.list(client : Client, user_id : String)
      url = "#{client.url}/api/v1/api-keys"
      response = MoanaClient.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::ApiKey).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/api-keys/#{@api_key_id}"

      response = MoanaClient.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end
  end
end
