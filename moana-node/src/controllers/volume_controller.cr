require "../brickutils"
require "../node_config"
require "../node_tasks"

class VolumeController < ApplicationController
  def create
    this_node = NodeConfig.from_conf
    if this_node.nil?
      result = {error: "failed to get node configuration"}
      return respond_with 500 do
        json result.to_json
      end
    end

    task = NodeTask.new(this_node.moana_url, this_node.cluster_id, ENV.fetch("WORKDIR", ""))
    begin
      task.volume_create(this_node, params["data"])
      respond_with 200 do
        json "{\"ok\": true}"
      end
    rescue ex: NodeTaskException
      result = {error: ex.message}
      return respond_with ex.status_code do
        json result.to_json
      end
    end
  end

  def start
    this_node = NodeConfig.from_conf
    if this_node.nil?
      result = {error: "failed to get node configuration"}
      return respond_with 500 do
        json result.to_json
      end
    end

    task = NodeTask.new(this_node.moana_url, this_node.cluster_id, ENV.fetch("WORKDIR", ""))
    begin
      task.volume_start(this_node, params["data"])
      respond_with 200 do
        json "{\"ok\": true}"
      end
    rescue ex: NodeTaskException
      result = {error: ex.message}
      return respond_with ex.status_code do
        json result.to_json
      end
    end
  end

  def stop
    this_node = NodeConfig.from_conf
    if this_node.nil?
      result = {error: "failed to get node configuration"}
      return respond_with 500 do
        json result.to_json
      end
    end

    task = NodeTask.new(this_node.moana_url, this_node.cluster_id, ENV.fetch("WORKDIR", ""))
    begin
      task.volume_stop(this_node, params["data"])
      respond_with 200 do
        json "{\"ok\": true}"
      end
    rescue ex: NodeTaskException
      result = {error: ex.message}
      return respond_with ex.status_code do
        json result.to_json
      end
    end
  end
end
