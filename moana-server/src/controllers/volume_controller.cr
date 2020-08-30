require "./volume_create_helpers"

VOLUME_CREATE = "volume_create"

class VolumeController < ApplicationController
  def index
    volumes = Volume.where(cluster_id: params["cluster_id"]).select
    respond_with 200 do
      json volumes.to_json
    end
  end

  def show
    if volume = Volume.find params["id"]
      respond_with 200 do
        json volume.to_json
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def create
    if !volume_params["replica_count"]?
      volume_params["replica_count"] = "1"
    end

    if !volume_params["disperse_count"]?
      volume_params["disperse_count"] = "1"
    end

    volume = Volume.new(volume_params.validate!)

    if volume.valid?
      volume_data = VolumeCreateData.new(volume_params)

      volume_data.validate

      if !volume_data.valid?
        results = {status: volume_data.error}
        respond_with 422 do
          json results.to_json
        end
      end

      task = Task.new(
        {
          "state" => "Queued",
          "type" => VOLUME_CREATE,
          "data" => volume_data.data.to_json,
          "response" => "{}"
        }
      )

      if cluster = Cluster.find params["cluster_id"]
        task.cluster = cluster
      else
        results = {status: "invalid cluster ID"}
        respond_with 422 do
          json results.to_json
        end
      end

      # TODO: Avoid SQL query here. if node_id is validated before
      if node = Node.find volume_data.data.bricks[0].node_id
        task.node = node
      else
        results = {status: "invalid Node ID"}
        respond_with 422 do
          json results.to_json
        end
      end

      if task.save
        respond_with 201 do
          json task.to_json
        end
      else
        results = {status: "failed to create task"}
        respond_with 500 do
          json results.to_json
        end
      end
    else
      results = {status: "invalid"}
      respond_with 422 do
        json results.to_json
      end
    end
  end

  def destroy
    if volume = Volume.find params["id"]
      volume.destroy
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

  def volume_params
    params.validation do
      required(:name, msg: nil, allow_blank: true)
      required(:bricks, msg: nil, allow_blank: true)
    end
  end
end
