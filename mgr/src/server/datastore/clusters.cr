require "uuid"

require "moana_types"

# WORKDIR/
#   - clusters/
#       - mycluster/
#           - info
module Datastore
  def self.cluster_dir(cluster_name)
    Path.new(@@rootdir, "clusters", cluster_name)
  end

  def self.cluster_file(cluster_name)
    Path.new(cluster_dir(cluster_name), "info")
  end

  def self.save_cluster(cluster)
    Dir.mkdir_p(cluster_dir(cluster.name))
    File.write(cluster_file(cluster.name), cluster.to_json)

    cluster
  end

  def self.list_clusters
    clusters = [] of MoanaTypes::Cluster
    Dir.entries(Path.new(@@rootdir, "clusters")).each do |cluster_name|
      if cluster_name != "." && cluster_name != ".."
        clusters << get_cluster(cluster_name).not_nil!
      end
    end

    clusters
  end

  def self.get_cluster(cluster_name)
    cluster_file_path = cluster_file(cluster_name)
    return nil unless File.exists?(cluster_file_path)

    MoanaTypes::Cluster.from_json(File.read(cluster_file_path).strip)
  end

  def self.create_cluster(cluster_name)
    cluster = get_cluster(cluster_name)
    return cluster unless cluster.nil?

    cluster_id = UUID.random.to_s
    cluster = MoanaTypes::Cluster.new
    cluster.id = cluster_id
    cluster.name = cluster_name
    save_cluster(cluster)
  end
end
