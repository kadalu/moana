class VolumeView < Granite::Base
  connection pg

  column id : String, primary: true
  column name : String
  column state : String
  column type : String
  column cluster_id : String
  column cluster_name : String
  column brick_id : String?
  column brick_path : String?
  column brick_device : String?
  column brick_port : Int32?
  column brick_state : String?
  column node_id : String?
  column node_hostname : String?
  column node_endpoint : String?

  select_statement <<-SQL
    SELECT volumes.id, volumes.name, volumes.state, volumes.type,
           clusters.id as cluster_id, clusters.name as cluster_name,
           bricks.id as brick_id, bricks.path as brick_path, bricks.device as brick_device, bricks.port as brick_port, bricks.state as brick_state,
           nodes.id as node_id, nodes.hostname as node_hostname, nodes.endpoint as node_endpoint
    FROM volumes
    LEFT OUTER JOIN clusters
    ON clusters.id = volumes.cluster_id
    LEFT OUTER JOIN bricks
    ON volumes.id = bricks.volume_id
    LEFT OUTER JOIN nodes
    ON bricks.node_id = nodes.id
  SQL

  def self.response(data, single=false)
    grouped_data = data.group_by do |rec|
      [rec.id, rec.name, rec.state, rec.type, rec.cluster_id, rec.cluster_name]
    end

    volumes = grouped_data.map do |key, value|
      value = value.select { |brick| !brick.brick_id.nil? }
      bricks_data = value.map do |brick|
        {
          "id" => brick.brick_id,
          "path" => brick.brick_path,
          "device" => brick.brick_device,
          "port" => brick.brick_port,
          "state" => brick.brick_state,
          "node" => {
            "id" => brick.node_id,
            "hostname" => brick.node_hostname,
            "endpoint" => brick.node_endpoint
          }
        }
      end

      {
        "id" => key[0],
        "name" => key[1],
        "state" => key[2],
        "type" => key[3],
        "cluster" => {
          "id" => key[4],
          "name" => key[5]
        },
        "bricks" => bricks_data
      }
    end

    return volumes[0] if single

    volumes
  end
end
