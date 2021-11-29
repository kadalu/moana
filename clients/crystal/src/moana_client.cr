require "moana_types"

require "./helpers"
require "./clusters"

module MoanaClient
  class Client
    property url, user_id, token

    def initialize(@url : String, @user_id : String, @token : String)
    end

    def initialize(@url : String)
      @user_id = ""
      @token = ""
    end

    def create_cluster(name : String)
      Cluster.create(self, name)
    end

    def list_clusters
      Cluster.list(self)
    end

    def cluster(name : String)
      Cluster.new(self, name)
    end
  end
end
