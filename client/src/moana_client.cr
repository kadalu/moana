require "./clusters"

module MoanaClient
  struct ClientContext
    property url : String = ""
  end

  class Client
    def initialize(url : String)
      @ctx = ClientContext.new
      @ctx.url = url
    end

    def cluster_create(name)
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
