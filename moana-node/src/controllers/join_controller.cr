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

    task = NodeTask.new(params["moana_url"], params["cluster_id"], ENV.fetch("WORKDIR", ""))
    begin
      node = task.node_join(node_name, node_endpoint)
      respond_with 201 do
        json node.to_json
      end
    rescue ex : MoanaClient::MoanaClientException
      result = {error: ex.message}
      return respond_with ex.status_code do
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
