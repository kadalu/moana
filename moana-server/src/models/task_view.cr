class TaskView < Granite::Base
  connection pg

  column id : String, primary: true
  column data : String
  column state : String
  column type : String
  column response : String
  column node_id : String
  column node_hostname : String
  column node_endpoint : String

  select_statement <<-SQL
    SELECT tasks.id, tasks.data, tasks.state, tasks.type, tasks.response,
           nodes.id as node_id, nodes.hostname as node_hostname, nodes.endpoint as node_endpoint
    FROM tasks
    INNER JOIN nodes
    ON tasks.node_id = nodes.id
    INNER JOIN clusters
    ON tasks.cluster_id = clusters.id
  SQL

  def self.response(data, single=false)
    data.map do |row|
      {
        "id" => row.id,
        "data" => row.data,
        "state" => row.state,
        "type" => row.type,
        "response" => row.response,
        "node" => {
          "id" => row.node_id,
          "hostname" => row.node_hostname,
          "endpoint" => row.node_endpoint
        }
      }
    end
  end
end
