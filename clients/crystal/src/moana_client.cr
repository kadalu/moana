require "moana_types"

require "./helpers"
require "./pools"
require "./users"

module MoanaClient
  class Client
    property url, user_id = "", token = "", username = "", api_key_id = ""

    def initialize(@url : String)
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
  end
end
