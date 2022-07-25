require "moana_types"

require "./helpers"
require "./pools"
require "./users"
require "./config_snapshots"

module MoanaClient
  class Client
    property url, user_id = "", token = "", username = "", api_key_id = ""

    def initialize(@url : String)
    end

    def info
      url = "#{@url}/api/v1"
      response = MoanaClient.http_get(
        url,
        headers: auth_header
      )
      if response.status_code == 200
        MoanaTypes::Info.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def create_pool(name : String)
      Pool.create(self, name)
    end

    def list_pools
      Pool.list(self)
    end

    def list_nodes(state = false)
      Node.list(self, state)
    end

    def list_volumes(state = false)
      Volume.list(self, state)
    end

    def pool(name : String)
      Pool.new(self, name)
    end

    def list_config_snapshots
      ConfigSnapshot.list(self)
    end

    def create_config_snapshot(name : String, overwrite = false)
      ConfigSnapshot.create(self, name, overwrite)
    end

    def config_snapshot(name : String)
      ConfigSnapshot.new(self, name)
    end

    def create_user(username : String, name : String, password : String)
      User.create(self, username, name, password)
    end

    def list_users
      User.list(self)
    end

    def user(user_id : String)
      User.new(self, user_id)
    end

    def login(username : String, password : String)
      api_key = User.login(self, username, password)
      @user_id = api_key.user_id
      @username = username
      @api_key_id = api_key.id
      @token = api_key.token

      api_key
    end

    def set_api_key(key)
      @user_id = key.user_id
      @api_key_id = key.id
      @token = key.token
      @username = key.username
    end

    def logged_in_user_id
      @user_id
    end

    def logged_in_user_api_key_id
      @api_key_id
    end

    def delete_user(username : String)
      User.delete(self, username)
    end
  end
end
