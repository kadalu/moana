module MoanaClient
  class ApiKey
    def initialize(@client : Client, @api_key_id : String)
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
  end
end
