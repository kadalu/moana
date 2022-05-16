module MoanaClient
  class ConfigSnapshot
    def initialize(@client : Client, @snap_name : String)
    end

    def self.create(client : Client, snap_name : String, overwrite = false)
      url = "#{client.url}/api/v1/config-snapshots"
      req = MoanaTypes::ConfigSnapshot.new
      req.name = snap_name
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

    def delete
      url = "#{@client.url}/api/v1/config-snapshots/#{@snap_name}"

      response = MoanaClient.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def self.list(client : Client)
      url = "#{client.url}/api/v1/config-snapshots"
      response = MoanaClient.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::ConfigSnapshot).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
