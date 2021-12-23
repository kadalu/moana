require "moana_types"

require "./helpers"
require "./pools"

module MoanaClient
  class Client
    property url, user_id, token

    def initialize(@url : String, @user_id : String, @token : String)
    end

    def initialize(@url : String)
      @user_id = ""
      @token = ""
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
  end
end
