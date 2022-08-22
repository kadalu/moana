module StorageManager
  class ConfigSnapshot
    def initialize(@client : Client, @snap_name : String)
    end

    def self.create(client : Client, snap_name : String, overwrite = false)
      url = "#{client.url}/api/v1/config-snapshots"
      req = MoanaTypes::ConfigSnapshot.new
      req.name = snap_name
      req.overwrite = overwrite

      response = StorageManager.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::ConfigSnapshot.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/config-snapshots/#{@snap_name}"

      response = StorageManager.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, snap_name : String)
      if snap_name
        url = "#{client.url}/api/v1/config-snapshots/#{snap_name}"
      else
        url = "#{client.url}/api/v1/config-snapshots"
      end

      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::ConfigSnapshot).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end
  end
end
