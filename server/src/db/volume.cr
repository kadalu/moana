require "json"
require "uuid"

require "moana_types"
require "sqlite3"

require "./node"
require "./option"

VOLUME_SELECT_QUERY = <<-SQL
    SELECT volumes.id,
           volumes.name,
           volumes.state,
           volumes.type,
           volumes.replica_count,
           volumes.disperse_count,
           volumes.brick_fs,
           volumes.fs_opts,
           bricks.id as brick_id,
           bricks.path as brick_path,
           bricks.device as brick_device,
           bricks.port as brick_port,
           bricks.state as brick_state,
           nodes.id as node_id,
           nodes.hostname as node_hostname,
           nodes.endpoint as node_endpoint
    FROM volumes
    INNER JOIN clusters
    ON clusters.id = volumes.cluster_id
    LEFT OUTER JOIN bricks
    ON volumes.id = bricks.volume_id
    LEFT OUTER JOIN nodes
    ON bricks.node_id = nodes.id
SQL

module MoanaDB
  struct VolumeView
    include DB::Serializable

    property id : String,
             name : String,
             state : String,
             type : String,
             replica_count : Int32,
             disperse_count : Int32,
             brick_fs : String,
             fs_opts : String,
             brick_id : String,
             brick_path : String,
             brick_device : String,
             brick_port : Int32,
             brick_state : String,
             node_id : String,
             node_hostname : String,
             node_endpoint : String
  end

  def self.create_table_volumes(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS volumes (
       id             UUID PRIMARY KEY,
       cluster_id     UUID,
       name           VARCHAR,
       type           VARCHAR,
       state          VARCHAR,
       replica_count  INTEGER,
       disperse_count INTEGER,
       brick_fs       VARCHAR,
       fs_opts        VARCHAR,
       created_at     TIMESTAMP,
       updated_at     TIMESTAMP
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS volumes_cluster_id_idx ON volumes (cluster_id);"
  end

  private def self.subvols(entry, bricks_data)
    subvol_type = entry.type.split(" ")[-1]
    subvol_bricks_count = entry.replica_count > 1 ? entry.replica_count : entry.disperse_count
    number_of_subvols = bricks_data.size / subvol_bricks_count

    (0 .. number_of_subvols-1).map do |sidx|
      subvol = MoanaTypes::Subvol.new

      subvol.replica_count = entry.replica_count
      subvol.disperse_count = entry.disperse_count
      subvol.type = subvol_type
      subvol.bricks = (0 .. subvol_bricks_count-1).map do |bidx|
        bricks_data[sidx * subvol_bricks_count + bidx]
      end

      subvol
    end
  end

  private def self.grouped_volumes(data : Array(VolumeView))
    grouped_data = data.group_by do |rec|
      [rec.id, rec.name, rec.state, rec.type, rec.replica_count.to_s, rec.disperse_count.to_s, rec.brick_fs, rec.fs_opts]
    end

    grouped_data.map do |key, rows|
      rows = rows.select { |brick| !brick.brick_id.nil? }
      bricks_data = rows.map do |brick|
        brk = MoanaTypes::Brick.new

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

      volume = MoanaTypes::Volume.new

      volume.id = rows[0].id
      volume.name = rows[0].name
      volume.state = rows[0].state
      volume.type = rows[0].type
      volume.subvols = subvols(rows[0], bricks_data)
      volume.replica_count = rows[0].replica_count
      volume.disperse_count = rows[0].disperse_count
      volume.brick_fs = rows[0].brick_fs
      volume.fs_opts = rows[0].fs_opts
      # Options from Options table
      volume.options = list_options(volume.id)

      volume
    end
  end

  def self.list_volumes(conn = @@conn)
    grouped_volumes(
      conn.not_nil!.query_all(VOLUME_SELECT_QUERY, as: VolumeView)
    )
  end

  def self.list_volumes(cluster_id : String, conn = @@conn)
    grouped_volumes(
      conn.not_nil!.query_all("#{VOLUME_SELECT_QUERY} WHERE volumes.cluster_id = ?", cluster_id, as: VolumeView)
    )
  end

  def self.get_volume(id : String, conn = @@conn)
    volumes = grouped_volumes(
      conn.not_nil!.query_all("#{VOLUME_SELECT_QUERY} WHERE id = ?", id, as: VolumeView)
    )

    return nil if volumes.size == 0
    volumes[0]
  end

  def self.create_volume(cluster_id : String, volume : Volume, conn = @@conn)
    v_query = "INSERT INTO volumes(id, cluster_id, name, type, state, replica_count, disperse_count, brick_fs, fs_opts, created_at, updated_at)
               VALUES             (?,  ?,          ?,    ?,    ?,     ?,             ?,              ?,        ?,       datetime(), datetime());"

    b_query = "INSERT INTO bricks(id, cluster_id, volume_id, idx, node_id, path, created_at, updated_at)
               VALUES            (?,  ?,          ?,         ?,   ?,       ?,    datetime(), datetime());"

    conn.not_nil!.transaction do |tx|
      cnn = tx.connection

      cnn.exec(
        v_query,
        volume.id,
        cluster_id,
        volume.name,
        volume.type,
        volume.state,
        volume.replica_count,
        volume.disperse_count,
        volume.brick_fs,
        volume.fs_opts
      )

      volume.subvols.each do |subvol|
        subvol.bricks.each_with_index do |brick, idx|
          cnn.exec(
            b_query,
            brick.id,
            cluster_id,
            volume.id,
            idx+1,
            brick.node.id,
            brick.path
          )
        end
      end
    end

    volume
  end

  def self.update_volume(id : String, state : String, conn = @@conn)
    query = "UPDATE volumes SET "
    params = [] of DB::Any

    query += "state = ?, "
    params << state

    params << id

    query += "updated_at = datetime() WHERE id = ?"

    conn.not_nil!.exec(query, args: params)

    get_volume(id)
  end

  def self.delete_volume(id : String, conn = @@conn)
    query = "DELETE FROM volumes WHERE id = ?"
    @@conn.not_nil!.exec(query, id)
  end
end
