require "moana_types"
require "moana_client"

require "./task"

struct NodeJoinTask < Task
  property type = "node_join"
  @parsed : MoanaTypes::NodeJoinRequest | Nil = nil

  def parsed
    if @parsed.nil?
      @parsed = MoanaTypes::NodeJoinRequest.from_json(@data)
    end

    @parsed.not_nil!
  end

  def run(node_conf)
    if node_conf.in_cluster?
      # TODO: Ignore as safe error if Cluster ID is same as already joined
      raise TaskException.new("Node is already part of a Cluster", 400)
    end

    begin
      client = MoanaClient::Client.new(parsed.moana_url)
      cluster = client.cluster(parsed.cluster_id)

      hostname = parsed.hostname
      endpoint = parsed.endpoint

      hostname = node_conf.hostname if hostname == ""
      endpoint = node_conf.endpoint if endpoint == ""

      # TODO: Also pass Token
      node = cluster.create_node(hostname, endpoint)
      node_conf.save(parsed.moana_url, parsed.cluster_id, node)
    rescue ex : MoanaClient::MoanaClientException
      raise TaskException.new("Failed to Join the cluster", ex.status_code)
    end
  end
end
