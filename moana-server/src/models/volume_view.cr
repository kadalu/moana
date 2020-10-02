require "json"
require "moana_types"

# include helps to include all the struct available
# into current namespace. Without this `MoanaTypes` prefix
# is required. For example, `MoanaTypes::VolumeResponse`
include MoanaTypes


class VolumeView < Granite::Base
  connection pg

  column id : String, primary: true
  column name : String
  column state : String
  column type : String
  column replica_count : Int32
  column disperse_count : Int32
  column cluster_id : String
  column cluster_name : String
  column brick_id : String
  column brick_path : String
  column brick_device : String
  column brick_port : Int32
  column brick_state : String
  column node_id : String
  column node_hostname : String
  column node_endpoint : String

  select_statement <<-SQL
    SELECT volumes.id, volumes.name, volumes.state, volumes.type, volumes.replica_count, volumes.disperse_count,
           clusters.id as cluster_id, clusters.name as cluster_name,
           bricks.id as brick_id, bricks.path as brick_path, bricks.device as brick_device, bricks.port as brick_port, bricks.state as brick_state,
           nodes.id as node_id, nodes.hostname as node_hostname, nodes.endpoint as node_endpoint
    FROM volumes
    INNER JOIN clusters
    ON clusters.id = volumes.cluster_id
    LEFT OUTER JOIN bricks
    ON volumes.id = bricks.volume_id
    LEFT OUTER JOIN nodes
    ON bricks.node_id = nodes.id
  SQL

  def self.response(data)
    grouped_data = data.group_by do |rec|
      [rec.id, rec.name, rec.state, rec.type, rec.cluster_id, rec.cluster_name, rec.replica_count.to_s, rec.disperse_count.to_s]
    end

    grouped_data.map do |key, value|
      value = value.select { |brick| !brick.brick_id.nil? }
      bricks_data = value.map do |brick|
        brk = BrickResponse.new

        brk.id = brick.brick_id
        brk.path = brick.brick_path
        brk.device = brick.brick_device
        brk.port = brick.brick_port
        brk.state = brick.brick_state
        brk.node.id = brick.node_id
        brk.node.hostname = brick.node_hostname
        brk.node.endpoint = brick.node_endpoint

        brk
      end

      subvol_type = value[0].type.split(" ")[-1]
      subvol_bricks_count = value[0].replica_count > 1 ? value[0].replica_count : value[0].disperse_count
      number_of_subvols = bricks_data.size / subvol_bricks_count

      subvols = (0 .. number_of_subvols-1).map do |sidx|
        subvol = SubvolResponse.new

        subvol.replica_count = value[0].replica_count
        subvol.disperse_count = value[0].disperse_count
        subvol.type = subvol_type
        subvol.bricks = (0 .. subvol_bricks_count-1).map do |bidx|
          bricks_data[sidx * subvol_bricks_count + bidx]
        end

        subvol
      end

      volume = VolumeResponse.new

      volume.id = value[0].id.to_s
      volume.name = value[0].name
      volume.state = value[0].state
      volume.type = value[0].type
      volume.cluster.id = value[0].cluster_id
      volume.cluster.name = value[0].cluster_name
      volume.subvols = subvols
      volume.options = {} of String => String
      volume.replica_count = value[0].replica_count
      volume.disperse_count = value[0].disperse_count

      volume
    end
  end
end
