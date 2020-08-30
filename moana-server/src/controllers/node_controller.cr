class NodeController < ApplicationController
  def index
    nodes = Node.where(cluster_id: params["cluster_id"]).select
    respond_with 200 do
      json nodes.to_json
    end
  end

  def show
    if node = Node.find params["id"]
      respond_with 200 do
        json node.to_json
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def create
    node = Node.new(node_params.validate!)
    if cluster = Cluster.find params["cluster_id"]
      node.cluster = cluster
    else
      results = {status: "invalid cluster ID"}
      respond_with 422 do
        json results.to_json
      end
    end

    if node.valid? && node.save
      respond_with 201 do
        json node.to_json
      end
    else
      results = {status: "invalid"}
      respond_with 422 do
        json results.to_json
      end
    end
  end

  def update
    if node = Node.find(params["id"])
      node.set_attributes(node_params.validate!)
      if node.valid? && node.save
        respond_with 200 do
          json node.to_json
        end
      else
        results = {status: "invalid"}
        respond_with 422 do
          json results.to_json
        end
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def destroy
    if node = Node.find params["id"]
      node.destroy
      respond_with 204 do
        json ""
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def node_params
    params.validation do
      required(:hostname, msg: nil, allow_blank: true)
      required(:endpoint, msg: nil, allow_blank: true)
      required(:cluster_id, msg: nil, allow_blank: true)
    end
  end
end
