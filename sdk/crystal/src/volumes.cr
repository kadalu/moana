module StorageManager
  class Volume
    def initialize(@client : Client, @pool_name : String, @name : String)
    end

    def self.create(client : Client, pool_name : String, volume : MoanaTypes::Volume)
      url = "#{client.url}/api/v1/pools/#{pool_name}/volumes"

      response = StorageManager.http_post(
        url,
        volume.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.create(client : Client, pool_name : String, name : String, dist_grps : Array(MoanaTypes::VolumeDistributeGroup), no_start = false)
      req = MoanaTypes::Volume.new
      req.name = name
      req.distribute_groups = dist_grps
      req.no_start = no_start
      create(client, pool_name, req)
    end

    def get_volfile(name : String, storage_unit = "")
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/volfiles/#{name}"
      url += "?storage_unit=#{storage_unit}" if storage_unit != ""

      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Volfile.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def get(state = false)
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, pool_name : String, state = false)
      url = "#{client.url}/api/v1/pools/#{pool_name}/volumes?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Volume).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, state = false)
      url = "#{client.url}/api/v1/volumes?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Volume).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def start_stop_volume(action)
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/#{action}"

      response = StorageManager.http_post(url, "{}", headers: @client.auth_header)
      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def start
      start_stop_volume("start")
    end

    def stop
      start_stop_volume("stop")
    end

    def set(volume_options : Hash(String, String))
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/options/set"

      response = StorageManager.http_post(
        url,
        volume_options.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def reset(volume_option_keys : Array(String))
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/options/reset"

      response = StorageManager.http_post(
        url,
        volume_option_keys.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}"

      response = StorageManager.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        StorageManager.error_response(response)
      end
    end

    def heal_start
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/heal/start"

      response = StorageManager.http_post(
        url,
        "{}",
        headers: @client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def heal_info
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/heal"

      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def rename(new_pool_name : String, new_volname : String)
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes/#{@name}/rename"

      response = StorageManager.http_post(
        url,
        {"new_pool_name": new_pool_name, "new_volname": new_volname}.to_json,
        headers: @client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def expand(volume : MoanaTypes::Volume)
      url = "#{@client.url}/api/v1/pools/#{@pool_name}/volumes"

      response = StorageManager.http_put(
        url,
        volume.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Volume.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end
  end
end
