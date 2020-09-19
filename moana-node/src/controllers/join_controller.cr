require "../brickutils"

class NodeRequest
  include JSON::Serializable

  property id : String, hostname : String, endpoint : String
end

class BrickRequest
  include JSON::Serializable

  property path : String, device : String, node : NodeRequest, mount_path : String = ""
end

class NodeResponse
  include JSON::Serializable

  property id : String,
           hostname : String,
           endpoint : String
end

class JoinController < ApplicationController
  def create
    unless join_params.valid?
      result = {error: params.errors[0].message}
      return respond_with 400 do
        json result.to_json
      end
    end

    node_name = ENV["NODENAME"] || ""
    node_endpoint = ENV["ENDPOINT"] || ""

    if node_name == "" || node_endpoint == ""
      result = {error: "NODENAME or ENDPOINT is not set"}
      return respond_with 400 do
        json result.to_json
      end
    end
    workdir = ENV.fetch("WORKDIR", ".")
    filename = "#{workdir}/node.json"

    if File.exists?(filename)
      # TODO: Ignore as safe error if Cluster ID is same as already joined
      result = {error: "Node is already part of a Cluster"}
      return respond_with 400 do
        json result.to_json
      end
    end

    req = {
      "hostname" => node_name,
      "endpoint" => node_endpoint
    }

    # Cluster_id and Token
    url = "#{params["moana_url"]}/api/clusters/#{params["cluster_id"]}/nodes"
    response = HTTP::Client.post(
      url,
      body: req.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"}
    )
    if response.status_code == 201
      node = NodeResponse.from_json(response.body)
      data = {
        "moana_url" => params["moana_url"],
        "cluster_id" => params["cluster_id"],
        "node_id" => node.id,
        "hostname" => node.hostname,
        "endpoint" => node.endpoint
      }

      File.write(filename, data.to_json())

      respond_with 201 do
        json response.body
      end
    else
      result = {error: "Failed to Join the cluster(Response: #{response.status_code})"}
      return respond_with 500 do
        json result.to_json
      end
    end
  end

  def join_params
    params.validation do
      required(:cluster_id, msg: "Cluster ID is not specified")
      required(:moana_url, msg: "Moana URL is not specified")
      required(:token, msg: "Join Token not specified")
    end
  end
end
