require "./api_keys"

module StorageManager
  class User
    def initialize(@client : Client, @user_id : String)
    end

    def self.list(client : Client)
      url = "#{client.url}/api/v1/users"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::User).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, pool_name : String)
      url = "#{client.url}/api/v1/pools/#{pool_name}/users"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::User).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.list(client : Client, pool_name : String, volume_name : String)
      url = "#{client.url}/api/v1/pools/#{pool_name}/volumes/#{volume_name}/users"
      response = StorageManager.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::User).from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.create(client : Client, username : String, name : String, password : String)
      url = "#{client.url}/api/v1/users"

      req = MoanaTypes::User.new
      req.name = name
      req.username = username
      req.password = password

      response = StorageManager.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::User.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def self.login(client : Client, username : String, password : String)
      url = "#{client.url}/api/v1/users/#{username}/api-keys"

      req = MoanaTypes::User.new
      req.password = password

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

    def logout
      url = "#{@client.url}/api/v1/api-keys/#{@client.api_key_id}"

      response = StorageManager.http_delete(
        url,
        headers: @client.auth_header
      )
      if response.status_code != 204
        StorageManager.error_response(response)
      end
      @client.api_key_id = ""
      @client.user_id = ""
      @client.username = ""
      @client.token = ""
    end

    def set_password(password : String, new_password : String)
      url = "#{@client.url}/api/v1/users/#{@client.username}/password"

      req = MoanaTypes::User.new
      req.password = password
      req.new_password = new_password

      response = StorageManager.http_post(
        url,
        req.to_json,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::User.from_json(response.body)
      else
        StorageManager.error_response(response)
      end
    end

    def create_api_key(name : String)
      ApiKey.create(@client, name)
    end

    def list_api_keys
      ApiKey.list(@client, @user_id)
    end

    def api_key(api_key_id : String)
      ApiKey.new(@client, api_key_id)
    end

    def add_role(pool_id : String, volume_id : String, role : String)
      Role.add(@client, @user_id, pool_id, volume_id, role)
    end

    def list_roles
      Role.list(@client, @user_id)
    end

    def role(pool_id : String, volume_id : String, role : String)
      Role.new(@client, @user_id, pool_id, volume_id, role)
    end

    def delete
      User.delete(@client, @client.username)
    end

    def self.delete(client : Client, username : String)
      url = "#{client.url}/api/v1/users/#{username}"

      response = StorageManager.http_delete(
        url,
        headers: client.auth_header
      )
      if response.status_code != 204
        StorageManager.error_response(response)
      end

      if username == client.username
        client.api_key_id = ""
        client.user_id = ""
        client.username = ""
        client.token = ""
      end
    end
  end
end
