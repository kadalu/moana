require "regex"

require "../volume_create_params"

VOLUME_CREATE = "volume_create"
VOLUME_START = "volume_start"

class VolumeController < ApplicationController
  def index
    volumes = VolumeView.all("WHERE volumes.cluster_id = ?", [params["cluster_id"]])
    respond_with 200 do
      json VolumeView.response(volumes).to_json
    end
  end

  def show
    volume = VolumeView.all("WHERE volumes.id = ?", [params["id"]])
    if volume.size > 0
      respond_with 200 do
        json VolumeView.response_single(volume).to_json
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def start
    # If Cluster ID is valid or not
    if tmp = Cluster.find params["cluster_id"]
      # TODO: Check if the logged in user is authorized for this Cluster
      cluster = tmp
    else
      result = {error: "Invalid Cluster ID"}
      return respond_with 422 do
        json result.to_json
      end
    end

    volume = VolumeView.all("WHERE volumes.id = ?", [params["id"]])
    if volume.size == 0
      results = {status: "not found"}
      return respond_with 404 do
        json results.to_json
      end
    end

    voldata = VolumeView.response(volume)[0]
    task = Task.new(
      {
        "state" => "Queued",
        "type" => VOLUME_START,
        "data" => voldata.to_json,
        "response" => "{}"
      }
    )

    task.cluster = cluster
    node = voldata.subvols[0].bricks[0].node
    task_node = Node.new
    task_node.id = node.id

    task.node = task_node

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
  end

  def create
    # Basic Validations
    unless volume_params.valid?
      result = {error: params.errors[0].message}
      return respond_with 400 do
        json result.to_json
      end
    end

    # If Cluster ID is valid or not
    if tmp = Cluster.find params["cluster_id"]
      # TODO: Check if the logged in user is authorized for this Cluster
      cluster = tmp
    else
      result = {error: "Invalid Cluster ID"}
      return respond_with 422 do
        json result.to_json
      end
    end

    # Initialize Gluster specific Validations
    begin
      volume_create_params = VolumeCreateParams.new params
    rescue JSON::Error
      result = {error: "Failed to parse JSON"}
      return respond_with 422 do
        json result.to_json
      end
    end

    # If Gluster specific validations are successful
    unless volume_create_params.valid?
      result = {error: volume_create_params.error}
      return respond_with 400 do
        json result.to_json
      end
    end

    task = Task.new(
      {
        "state" => "Queued",
        "type" => VOLUME_CREATE,
        "data" => volume_create_params.volume.to_json,
        "response" => "{}"
      }
    )

    task.cluster = cluster
    task.node = volume_create_params.first_node

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
      required(:cluster_id, msg: "Cluster ID is not specified")
      required(:name, msg: "Volume name is not specified")
      required(:bricks, msg: "Bricks not specified")
    end
  end
end
