module StorageManager
  class Pool
    def initialize(@client : Client, @name : String)
    end

    def self.create(client : Client, pool : MoanaTypes::Pool)
      url = "#{client.url}/api/v1/pools"

      response = StorageManager.http_post(
        url,
        pool.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.create(client : Client, name : String, dist_grps : Array(MoanaTypes::PoolDistributeGroup), no_start = false)
      req = MoanaTypes::Pool.new
      req.name = name
      req.distribute_groups = dist_grps
      req.no_start = no_start
      create(client, pool_name, req)
    end

    def get_volfile(name : String, storage_unit = "")
      url = "#{@client.url}/api/v1/pools/#{@name}/volfiles/#{name}"
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
      url = "#{@client.url}/api/v1/pools/#{@name}?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, state = false)
      url = "#{client.url}/api/v1/pools?state=#{state ? 1 : 0}"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Pool).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def start_stop_pool(action)
      url = "#{@client.url}/api/v1/pools/#{@name}/#{action}"

      response = StorageManager.http_post(url, "{}", headers: @client.auth_header)
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def start
      start_stop_pool("start")
    end

    def stop
      start_stop_pool("stop")
    end

    def set(pool_options : Hash(String, String))
      url = "#{@client.url}/api/v1/pools/#{@name}/options/set"

      response = StorageManager.http_post(
        url,
        pool_options.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def reset(pool_option_keys : Array(String))
      url = "#{@client.url}/api/v1/pools/#{@name}/options/reset"

      response = StorageManager.http_post(
        url,
        pool_option_keys.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def delete
      url = "#{@client.url}/api/v1/pools/#{@name}"

      response = StorageManager.http_delete(
        url,
        headers: @client.auth_header
      )

      if response.status_code != 204
        StorageManager.error_response(response)
      end
    end

    def heal_start
      url = "#{@client.url}/api/v1/pools/#{@name}/heal/start"

      response = StorageManager.http_post(
        url,
        "{}",
        headers: @client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def heal_info
      url = "#{@client.url}/api/v1/pools/#{@name}/heal"

      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def rename(new_pool_name : String)
      url = "#{@client.url}/api/v1/pools/#{@name}/rename"

      response = StorageManager.http_post(
        url,
        {"new_name": new_pool_name}.to_json,
        headers: @client.auth_header
      )

      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def expand(pool : MoanaTypes::Pool)
      url = "#{@client.url}/api/v1/pools"

      response = StorageManager.http_put(
        url,
        pool.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def pool_rebalance_start_stop(action)
      url = "#{@client.url}/api/v1/pools/#{@name}/rebalance_#{action}"

      response = StorageManager.http_post(url, "{}", headers: @client.auth_header)
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def rebalance_start
      pool_rebalance_start_stop("start")
    end

    def rebalance_stop
      pool_rebalance_start_stop("stop")
    end

    def rebalance_status
      url = "#{@client.url}/api/v1/pools/#{@name}/rebalance_status"

      response = StorageManager.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Pool.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end
  end
end
