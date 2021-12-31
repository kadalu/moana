require "./nodes"
require "./volumes"

module MoanaClient
  class Pool
    def initialize(@client : Client, @name : String)
    end

    def self.list(client : Client)
      url = "#{client.url}/api/v1/pools"
      response = MoanaClient.http_get(
        url,
        headers: client.auth_header
      )
      if response.status_code == 200
        Array(MoanaTypes::Pool).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.create(client : Client, name : String)
      url = "#{client.url}/api/v1/pools"

      req = MoanaTypes::PoolCreateRequest.new
      req.name = name

      response = MoanaClient.http_post(
        url,
        req.to_json,
        headers: client.auth_header
      )
      if response.status_code == 201
        MoanaTypes::Pool.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def node(node_name)
      Node.new(@client, @name, node_name)
    end

    def add_node(name : String, endpoint : String)
      Node.add(@client, @name, name, endpoint)
    end

    def list_nodes(state = false)
      Node.list(@client, @name, state)
    end

    def list_volumes(state = false)
      Volume.list(@client, @name, state)
    end

    def create_volume(req : MoanaTypes::Volume)
      Volume.create(@client, @name, req)
    end

    def create_volume(name : String, dist_grps : Array(MoanaTypes::VolumeDistributeGroup), no_start = false)
      Volume.create(@client, @name, name, dist_grps, no_start)
    end

    def volume(name : String)
      Volume.new(@client, @name, name)
    end

    def get_volfile(name : String)
      url = "#{@client.url}/api/v1/pools/#{@name}/volfiles/#{name}"
      response = MoanaClient.http_get(
        url,
        headers: @client.auth_header
      )
      if response.status_code == 200
        MoanaTypes::Volfile.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
