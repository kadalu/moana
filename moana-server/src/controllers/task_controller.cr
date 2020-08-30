class TaskController < ApplicationController
  def index
    if params["node_id"]?
      tasks = Task.where(cluster_id: params["cluster_id"])
                .where(node_id: params["node_id"]).select
    else
      tasks = Task.where(cluster_id: params["cluster_id"]).select
    end

    respond_with 200 do
      json tasks.to_json
    end
  end

  def show
    if task = Task.find params["id"]
      respond_with 200 do
        json task.to_json
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
      required(:data, msg: nil, allow_blank: true)
      required(:state, msg: nil, allow_blank: true)
      required(:type, msg: nil, allow_blank: true)
      required(:response, msg: nil, allow_blank: true)
    end
  end
end
