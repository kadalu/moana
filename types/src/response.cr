require "json"
require "db"

module MoanaTypes
  struct Node
    include JSON::Serializable
    include DB::Serializable

    property id = "", hostname = "", endpoint = "", cluster_id = ""

    def initialize(@id : String = "", @hostname : String = "", @endpoint : String = "", @cluster_id : String = "")
    end
  end

  struct Cluster
    include JSON::Serializable

    getter id, name
    property nodes = [] of Node

    def initialize(@id : String, @name : String)
    end
  end

  struct Task
    include JSON::Serializable
    include DB::Serializable

    property id : String, node_id : String, type : String, state : String, data : String, response : String
  end

  struct Brick
    include JSON::Serializable

    property id = "",
             path = "",
             device = "",
             node = Node.new,
             port : Int32 = 0,
             state = "",
             type = ""

    def initialize
    end
  end

  struct Subvol
    include JSON::Serializable

    property replica_count : Int32 = 1,
             disperse_count : Int32 = 1,
             type = "",
             bricks = [] of Brick

    def initialize
    end
  end

  struct Volume
    include JSON::Serializable

    property id = "",
             name = "",
             replica_count : Int32 = 1,
             disperse_count : Int32 = 1,
             state = "",
             type = "",
             brick_fs = "",
             fs_opts = "",
             subvols = [] of Subvol

    def initialize
    end

    def participating_nodes
      node_ids = [] of String
      @subvols.each do |subvol|
        subvol.bricks.each do |brick|
          node_ids << brick.node.id
        end
      end

      node_ids
    end

    def first_node_id
      node_id = ""
      @subvols.each do |subvol|
        subvol.bricks.each do |brick|
          node_id = brick.node.id
          break
        end
      end

      node_id
    end
  end

  
  struct Error
    include JSON::Serializable

    property error : String, status_code : Int32 = 0
  end

  struct Volfile
    include JSON::Serializable

    property content : String
  end
end
