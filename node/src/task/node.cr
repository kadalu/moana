require "moana_types"
require "moana_client"

struct NodeJoinTask

  def run(moana_url, cluster_id, node_conf)
    if !node_conf.nil?
      # TODO: Ignore as safe error if Cluster ID is same as already joined
      raise TaskException.new("Node is already part of a Cluster", 400)
    end

    req = Node.from_json(@data)

    begin
      client = MoanaClient::Client.new(moana_url)
      cluster = client.cluster(cluster_id)
      node = cluster.node_create(req.hostname, req.endpoint)
      node_conf.save(node)

      node
    rescue ex : MoanaClient::MoanaClientException
      raise TaskException.new("Failed to Join the cluster", ex.status_code)
    end
  end
end
