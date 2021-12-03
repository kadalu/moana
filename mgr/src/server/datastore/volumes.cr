require "uuid"

require "moana_types"

module Datastore
  def self.volume_dir(pool_name, volume_name)
    Path.new(@@rootdir, "pools", pool_name, "volumes", volume_name)
  end

  def self.volume_file(pool_name, volume_name)
    Path.new(volume_dir(pool_name, volume_name), "info")
  end

  def self.save_volume(pool_name, volume)
    Dir.mkdir_p(volume_dir(pool_name, volume.name))
    File.write(volume_file(pool_name, volume.name), volume.to_json)

    volume
  end

  def self.list_volumes(pool_name)
    volumes = [] of MoanaTypes::Volume
    volumes_dir = Path.new(@@rootdir, "pools", pool_name, "volumes")

    return volumes unless File.exists?(volumes_dir)

    Dir.entries(volumes_dir).each do |volume_name|
      if volume_name != "." && volume_name != ".."
        volumes << get_volume(pool_name, volume_name).not_nil!
      end
    end

    volumes
  end

  def self.get_volume(pool_name, volume_name)
    volume_file_path = volume_file(pool_name, volume_name)
    return nil unless File.exists?(volume_file_path)

    MoanaTypes::Volume.from_json(File.read(volume_file_path).strip)
  end

  def self.create_volume(pool_name, volume)
    vol = get_volume(pool_name, volume.name)
    raise DatastoreError.new("Volume already exists") unless vol.nil?

    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        # Do not store the redundant node information.
        # node_name is already available.
        storage_unit.node = MoanaTypes::Node.new
      end
    end
    save_volume(pool_name, volume)
  end
end
