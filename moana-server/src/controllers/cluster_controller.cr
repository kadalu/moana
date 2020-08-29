class ClusterController < ApplicationController
  def index
    clusters = Cluster.all
    respond_with 200 do
      json clusters.to_json
    end
  end

  def show
    if cluster = Cluster.find params["id"]
      respond_with 200 do
        json cluster.to_json
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def create
    cluster = Cluster.new(cluster_params.validate!)
    puts cluster.valid?
    puts cluster.save!
    if cluster.valid? && cluster.save
      respond_with 201 do
        json cluster.to_json
      end
    else
      results = {status: "invalid"}
      respond_with 422 do
        json results.to_json
      end
    end
  end

  def update
    if cluster = Cluster.find(params["id"])
      cluster.set_attributes(cluster_params.validate!)
      if cluster.valid? && cluster.save
        respond_with 200 do
          json cluster.to_json
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
    if cluster = Cluster.find params["id"]
      cluster.destroy
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

  def cluster_params
    params.validation do
      required(:name, msg: nil, allow_blank: true)
    end
  end
end
