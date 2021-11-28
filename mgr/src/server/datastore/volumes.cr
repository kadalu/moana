require "uuid"

require "moana_types"

module Datastore
  def self.volume_dir(cluster_name, volume_name)
    Path.new(@@rootdir, "clusters", cluster_name, "volumes", volume_name)
  end

  def self.volume_file(cluster_name, volume_name)
    Path.new(volume_dir(cluster_name, volume_name), "info")
  end

  def self.save_volume(cluster_name, volume)
    Dir.mkdir_p(volume_dir(cluster_name, volume.name))
    File.write(volume_file(cluster_name, volume.name), volume.to_json)

    volume
  end

  def self.get_volume(cluster_name, volume_name)
    volume_file_path = volume_file(cluster_name, volume_name)
    return nil unless File.exists?(volume_file_path)

    MoanaTypes::Volume.from_json(File.read(volume_file_path).strip)
  end

  def self.create_volume(cluster_name, volume)
    vol = get_volume(cluster_name, volume.name)
    raise DatastoreError.new("Volume already exists") unless vol.nil?

    volume.distribute_groups.each do |dist_grp|
      dist_grp.storage_units.each do |storage_unit|
        # Do not store the redundant node information.
        # node_name is already available.
        storage_unit.node = MoanaTypes::Node.new
      end
    end
    save_volume(cluster_name, volume)
  end
end
