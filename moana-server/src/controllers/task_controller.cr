require "../volume_create_params"
require "../task_response_handlers"

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
          begin
            case task.type
            when VOLUME_CREATE
              task_volume_create(task)

            when VOLUME_START
              task_volume_start(task)

            when VOLUME_STOP
              task_volume_stop(task)
            end
          rescue ex : TaskResponseHandlerException
            results = {status: "#{ex}"}
            return respond_with 500 do
              json results.to_json
            end
          end
        end

        return respond_with 200 do
          json task.to_json
        end
      else
        results = {status: "failed to update task"}
        respond_with 500 do
          json results.to_json
        end
      end
    else
      results = {status: "task not found"}
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
