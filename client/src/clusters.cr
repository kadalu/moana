require "http/client"

require "moana_types"

require "./helpers"
require "./volumes"
require "./nodes"
require "./tasks"

module MoanaClient
  class Cluster
    def initialize(@ctx : ClientContext, @cluster_id : String)
    end

    def self.create(ctx : ClientContext, name : String)
      response = MoanaClient.http_post(
        "#{ctx.url}/api/v1/clusters",
        {name: name}.to_json,
        headers: MoanaClient.auth_header(ctx)
      )
      if response.status_code == 201
        MoanaTypes::Cluster.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def get
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}"
      response = MoanaClient.http_get(url, headers: MoanaClient.auth_header(@ctx))
      if response.status_code == 200
        MoanaTypes::Cluster.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def self.all(ctx : ClientContext)
      url = "#{ctx.url}/api/v1/clusters"
      response = MoanaClient.http_get(url, headers: MoanaClient.auth_header(ctx))
      if response.status_code == 200
        Array(MoanaTypes::Cluster).from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def update(name)
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}"
      response = MoanaClient.http_put(
        url,
        {name: name}.to_json,
        headers: MoanaClient.auth_header(@ctx)
      )

      if response.status_code == 200
        MoanaTypes::Cluster.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def delete
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}"
      response = MoanaClient.http_delete(url, headers: MoanaClient.auth_header(@ctx))

      if response.status_code != 204
        MoanaClient.error_response(response)
      end
    end

    def create_volume(req)
      Volume.create(@ctx, req)
    end

    def volume(id : String)
      Volume.new(@ctx, @cluster_id, id)
    end

    def volumes
      Volume.all(@ctx, @cluster_id)
    end

    def join_node(endpoint : String, token : String)
      Node.join(@ctx, @cluster_id, endpoint, token)
    end

    def create_node(hostname : String, endpoint : String)
      Node.create(@ctx, @cluster_id, hostname, endpoint)
    end

    def node(id : String)
      Node.new(@ctx, @cluster_id, id)
    end

    def nodes
      Node.all(@ctx, @cluster_id)
    end

    def task(id : String)
      Task.new(@ctx, @cluster_id, id)
    end

    def tasks
      Task.all(@ctx, @cluster_id)
    end

    def volfile(name : String)
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/volfiles/#{name}"
      response = MoanaClient.http_get(url, headers: MoanaClient.auth_header(@ctx))

      if response.status_code == 200
        MoanaTypes::Volfile.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end

    def invite_node
      url = "#{@ctx.url}/api/v1/clusters/#{@cluster_id}/invites"
      response = MoanaClient.http_post(url, "{}", headers: MoanaClient.auth_header(@ctx))

      if response.status_code == 200
        MoanaTypes::Token.from_json(response.body)
      else
        MoanaClient.error_response(response)
      end
    end
  end
end
