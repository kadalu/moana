require "./clusters"
require "./users"
require "./roles"

module MoanaClient
  struct ClientContext
    property url, user_id, token, node_id

    def initialize(@url : String, @user_id : String, @token : String, @node_id : String)
    end
  end

  class Client
    def initialize(url : String, user_id : String, token : String, node_id : String = "")
      @ctx = ClientContext.new(url, user_id, token, node_id)
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

    def create_user(name, email, password)
      User.create(@ctx, name, email, password)
    end

    def user(id : String)
      User.new(@ctx, id)
    end

    def add_role(user_id, cluster_id, volume_id, role)
      Role.create(@ctx, user_id, cluster_id, volume_id, role)
    end

    def role(user_id : String, cluster_id : String, volume_id : String, role : String)
      Role.new(@ctx, user_id, cluster_id, volume_id, role)
    end
  end
end
