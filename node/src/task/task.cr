require "json"

class TaskException < Exception
  property http_status_code

  def initialize(@message : String, @http_status_code : Int32)
    super(@message)
  end
end

abstract struct Task
  include JSON::Serializable

  property data = ""

  use_json_discriminator "type", {
    node_join: NodeJoinTask,
    volume_create: VolumeCreateTask,
    volume_start: VolumeStartTask,
    volume_stop: VolumeStopTask
  }

  abstract def run(node_conf : NodeConfig)
end
