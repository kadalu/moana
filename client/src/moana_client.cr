require "./clusters"

module MoanaClient
  struct ClientContext
    property url, user_id, token

    def initialize(@url : String, @user_id : String, @token : String)
    end
  end

  class Client
    def initialize(url : String, user_id : String, token : String)
      @ctx = ClientContext.new(url, user_id, token)
    end

    def initialize(url : String)
      @ctx = ClientContext.new(url, "", "")
    end
    
    def create_cluster(name)
      Cluster.create(@ctx, name)
    end

    def cluster(id : String)
      Cluster.new(@ctx, id)
    end

    def clusters()
      Cluster.all(@ctx)
    end
  end
end
