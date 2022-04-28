module MoanaClient
  class Backups
    def initialize(@client : Client, @name : String)
    end

    def self.backup(client : Client, name : String)
      url = "#{client.url}/api/v1/backups"

      response = MoanaClient.http_post(
        url,
        {"name": name}.to_json,
        headers: client.auth_header
      )

      if response.status_code == 200
        Hash(String, String).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.restore(client : Client, name : String)
      url = "#{client.url}/api/v1/backups/#{name}/restore"

      response = MoanaClient.http_post(
        url,
        {"name": name}.to_json,
        headers: client.auth_header
      )

      if response.status_code != 200
        MoanaClient.error_response(response)
      end
    end
  end
end
