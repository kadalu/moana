require "../volume_create_params"

class TaskController < ApplicationController
  def index
    if params["node_id"]?
      tasks = TaskView.all("WHERE clusters.id = ? AND nodes.id = ?", [params["cluster_id"], params["node_id"]])
    else
      tasks = TaskView.all("WHERE clusters.id = ?", [params["cluster_id"]])
    end

    respond_with 200 do
      json TaskView.response(tasks).to_json
    end
  end

  def show
    task = TaskView.all("WHERE tasks.id = ?", [params["id"]])
    if task.size > 0
      respond_with 200 do
        json TaskView.response_single(task).to_json
      end
    else
      results = {status: "not found"}
      respond_with 404 do
        json results.to_json
      end
    end
  end

  def update
    if task = Task.find(params["id"])
      task.set_attributes(task_params.validate!)
      if task.valid? && task.save
        if task.state == "Success"
          if taskdata = task.data
            # TODO: Use Db Transaction to insert all these
            volreq = VolumeRequest.from_json(taskdata)
            volume = Volume.new(
              {
                "id" => volreq.id,
                "name" => volreq.name,
                "state" => "Created",
                "type" => volreq.type,
                "replica_count" => volreq.replica_count,
                "disperse_count" => volreq.disperse_count
              }
            )

            volume.cluster = Cluster.new(
              {
                "id" => volreq.cluster_id
              }
            )

            if !volume.save
              results = {status: "failed to save volume"}
              respond_with 500 do
                json results.to_json
              end
            end

            volreq.bricks.each do |brickreq|
              brick = Brick.new(
                {
                  "path" => brickreq.path == "" ? "-" : brickreq.path,
                  "device" => brickreq.device == "" ? "-" : brickreq.device,
                  "port" => brickreq.port,
                  "state" => "-"
                }
              )
              brick.cluster = volume.cluster

              brick.volume = volume
              if node = brickreq.node
                brick.node = Node.new(
                  {
                    "id" => node.id
                  }
                )
              end
              if !brick.save
                results = {status: "failed to save brick"}
                respond_with 500 do
                  json results.to_json
                end
              end
            end
          end
        end

        respond_with 200 do
          json task.to_json
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
    if task = Task.find params["id"]
      task.destroy
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

  def task_params
    params.validation do
      #required(:data, msg: nil, allow_blank: true)
      required(:state, msg: nil, allow_blank: true)
      #required(:type, msg: nil, allow_blank: true)
      required(:response, msg: nil, allow_blank: true)
    end
  end
end
