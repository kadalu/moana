require "regex"

VOLUME_CREATE = "volume_create"

class BrickRequest
  include JSON::Serializable

  property node_id : String
  property path : String?
  property device : String?
end

class VolumeCreateRequest
  include JSON::Serializable

  property name, replica_count, disperse_count, brick_fs, bricks

  def initialize(@name : String,
                 @replica_count : Int32 = 1,
                 @disperse_count : Int32 = 1,
                 @brick_fs : String = "dir",
                 @bricks = [] of BrickRequest
                )
  end
end

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
    # Set default Options: replica_count, disperse_count
    if !params["replica_count"]?
      params["replica_count"] = "1"
    end

    if !params["disperse_count"]?
      params["disperse_count"] = "1"
    end

    if !params["brick_fs"]?
      params["brick_fs"] = "dir"
    end

    volume_params.validate!

    volume_data = VolumeCreateRequest.new(
      params["name"],
      params["replica_count"].to_i,
      params["disperse_count"].to_i,
      params["brick_fs"]
    )
    volume_data.bricks = @bricks

    if params.valid?
      task = Task.new(
        {
          "state" => "Queued",
          "type" => VOLUME_CREATE,
          "data" => volume_data.to_json,
          "response" => "{}"
        }
      )

      if cluster = Cluster.find params["cluster_id"]
        task.cluster = cluster
      else
        results = {status: "invalid cluster ID"}
        return respond_with 422 do
          json results.to_json
        end
      end

      # TODO: Avoid SQL query here. if node_id is validated before
      if node = Node.find volume_data.bricks[0].node_id
        if node.cluster_id != params["cluster_id"]
          results = {status: "Node ID belongs to different Cluster or invalid"}
          return respond_with 422 do
            json results.to_json
          end
        end

        task.node = node
      else
        results = {status: "invalid Node ID"}
        return respond_with 422 do
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

  @bricks = [] of BrickRequest

  def setbricks(value)
    @bricks = Array(BrickRequest).from_json(value)
  end

  def volume_params
    params.validation do
      required(:cluster_id, msg: "Cluster ID is not specified")

      required(:name, msg: "Invalid Volume name") do |value|
        !(/^[[:alpha:]][[:alnum:]]+$/ =~ value).nil?
      end

      required(:bricks, msg: "bricks not specified") do |value|
        setbricks value
        @bricks.size > 0
      end

      optional(:brick_fs, msg: "Unsupported Brick FS") do |value|
        ["zfs", "xfs", "ext4", "dir"].includes?(value)
      end

      required(:bricks, msg: "Brick path not specified") do |value|
        if @params["brick_fs"] == "dir"
          non_path = @bricks.find { |brick| brick.path.nil? }
          non_path.nil?
        else
          true
        end
      end

      required(:bricks, msg: "Brick device not specified") do |value|
        if @params["brick_fs"] != "dir"
          non_dev = @bricks.find { |brick| brick.device.nil? }
          non_dev.nil?
        else
          true
        end
      end

      optional(:replica_count, msg: "Bricks count not matching with replica count") do |value|
        value.to_i == 1 || @bricks.size % value.to_i == 0
      end

      optional(:disperse_count, msg: "Bricks count not matching with disperse count") do |value|
        value.to_i == 1 || @bricks.size % value.to_i == 0
      end
    end
  end
end
