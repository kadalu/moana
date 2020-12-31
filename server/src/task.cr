require "json"

abstract struct ServerTask
  include JSON::Serializable

  property id : String, node_id : String, type : String, state : String, data : String, response : String, cluster_id : String

  abstract def on_complete
end

struct VolumeCreateTask < ServerTask
  property type = "volume_create"

  def on_complete
    volume = MoanaTypes::Volume.from_json(@data)
    volume.state = "Created"
    MoanaDB.create_volume(@cluster_id, volume)
  end
end

struct VolumeStartTask < ServerTask
  property type = "volume_start"

  def on_complete
    volume = MoanaTypes::Volume.from_json(@data)
    MoanaDB.update_volume(volume.id, "Started")
  end
end

struct VolumeStopTask < ServerTask
  property type = "volume_stop"

  def on_complete
    volume = MoanaTypes::Volume.from_json(@data)
    MoanaDB.update_volume(volume.id, "Stopped")
  end
end

abstract struct ServerTask
  {% begin %}
    # Macro for creating the Map with list of Subclasses
    use_json_discriminator "type", {
      {% for name in @type.subclasses %}
      {{ name.stringify.gsub(/Task$/, "").underscore.id }}: {{ name.id }},
      {% end %}
    }
  {% end %}
end
