module MoanaClient
  class ConfigSnapshot
    def initialize(@client : Client, @name : String)
    end

    def self.create(client : Client, name : String, overwrite = false)
      url = "#{client.url}/api/v1/config-snapshots"
      req = MoanaTypes::ConfigSnapshot.new
      req.name = name
      req.overwrite = overwrite

      response = MoanaClient.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::ConfigSnapshot.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
