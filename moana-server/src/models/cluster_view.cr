class ClusterView < Granite::Base
  connection pg

  column id : String, primary: true
  column name : String
  column node_id : String?
  column node_hostname : String?
  column node_endpoint : String?

  select_statement <<-SQL
    SELECT clusters.id, clusters.name, nodes.id as node_id, nodes.hostname as node_hostname, nodes.endpoint as node_endpoint
    FROM clusters
    LEFT OUTER JOIN nodes
    ON clusters.id = nodes.cluster_id
  SQL

  def self.response(data, single=false)
    grouped_data = data.group_by do |rec|
      [rec.id, rec.name]
    end

    clusters = grouped_data.map do |key, value|
      value = value.select { |node| !node.node_id.nil? }
      nodes_data = value.map do |node|
        {"id" => node.node_id, "hostname" => node.node_hostname, "endpoint" => node.node_endpoint}
      end

      {
        "id" => key[0],
        "name" => key[1],
        "nodes" => nodes_data
      }
    end

    return clusters[0] if single

    clusters
  end
end
