require "uuid"
require "moana_types"
require "db"
require "sqlite3"

module Datastore
  def dump(from_db, to_db)
    DB.connect "sqlite3://#{to_db}" do |to_conn|
      to_conn = to_conn.as(SQLite3::Connection)
      DB.connect "sqlite3://#{from_db}" do |from_conn|
        from_conn = from_conn.as(SQLite3::Connection)
        from_conn.dump(to_conn)
      end
    end
  end

  private def sort_config_snapshots(snaps)
    snaps.sort do |snap_a, snap_b|
      snap_b.created_on <=> snap_a.created_on
    end
  end

  def list_config_snapshots
    snaps = Dir.children("#{@@rootdir}/config-snapshots").map do |snap_name|
      snap = MoanaTypes::ConfigSnapshot.from_json(
        File.read("#{@@rootdir}/config-snapshots/#{snap_name}/meta.json")
      )
      snap.name = snap_name

      snap
    end
    sort_config_snapshots(snaps)
  end

  def list_config_snapshots(snap_list_name)
    snap_arr = [] of MoanaTypes::ConfigSnapshot

    if !Dir.exists?("#{GlobalConfig.workdir}/config-snapshots/#{snap_list_name}")
      return snap_arr
    end

    snap = MoanaTypes::ConfigSnapshot.from_json(
      File.read("#{@@rootdir}/config-snapshots/#{snap_list_name}/meta.json")
    )
    snap.name = snap_list_name

    snap_arr << snap
  end
end
