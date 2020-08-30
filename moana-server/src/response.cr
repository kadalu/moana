require "json"

class NodeRecord
  include JSON::Serializable

  property id, hostname, endpoint

  def initialize(@id : String?, @hostname : String?, @endpoint : String?)
  end
end

class ClusterRecord
  include JSON::Serializable

  property id, name, nodes

  def initialize(@id : String, @name : String, @nodes : Array(NodeRecord))
  end
end

def clusters_response(data, single = false)
  clusters = Hash(String, ClusterRecord).new
  data.each do |row|
    if cluster_id = row.id
      if !clusters.has_key?(row.id)
        clusters[cluster_id] = ClusterRecord.new cluster_id, row.name, [] of NodeRecord
      end

      if row.node_id
        clusters[cluster_id].nodes << NodeRecord.new(row.node_id, row.hostname, row.endpoint)
      end
    end
  end

  return clusters.first_value if single

  clusters.map do |key, value|
    value
  end
end
