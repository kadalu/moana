require "json"

module MoanaTypes
  struct ClusterCreateRequest
    include JSON::Serializable

    property name = ""

    def initialize
    end
  end

  struct Cluster
    include JSON::Serializable

    property id = "", name = ""

    def initialize(@id : String, @name : String)
    end

    def initialize
    end
  end

  struct Error
    include JSON::Serializable

    property error : String, status_code : Int32 = 0
  end
end
