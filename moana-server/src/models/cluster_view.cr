class ClusterView < Granite::Base
  connection pg

  column id : String, primary: true
  column name : String
  column node_id : String?
  column hostname : String?
  column endpoint : String?

  select_statement <<-SQL
    SELECT clusters.id, clusters.name, nodes.id as node_id, nodes.hostname, nodes.endpoint
    FROM clusters
    LEFT OUTER JOIN nodes
    ON clusters.id = nodes.cluster_id
  SQL
end
