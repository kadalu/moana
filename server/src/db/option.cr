require "json"
require "uuid"

require "sqlite3"

OPTION_SELECT_QUERY = <<-SQL
  SELECT name,
         value
  FROM options
SQL

module MoanaDB
  struct OptionView
    include JSON::Serializable
    include DB::Serializable

    property name = "",
             value = ""
  end

  def self.create_table_options(conn = @@conn)
    conn.not_nil!.exec "CREATE TABLE IF NOT EXISTS options (
       cluster_id UUID,
       volume_id  UUID,
       name       VARCHAR,
       value      VARCHAR
       created_at TIMESTAMP,
       updated_at TIMESTAMP,
       PRIMARY KEY (volume_id, name)
    );"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS options_cluster_id_idx ON options (cluster_id);"
    conn.not_nil!.exec "CREATE INDEX IF NOT EXISTS options_volume_id_idx ON options (volume_id);"
  end

  def self.list_options(volume_id : String, conn = @@conn)
    opts = conn.not_nil!.query_all("#{OPTION_SELECT_QUERY} WHERE volume_id = ?", volume_id, as: OptionView)
    options = {} of String => String
    opts.each do |opt|
      options[opt.name] = opt.value
    end

    options
  end

  def self.create_option(cluster_id : String, volume_id : String, opts : Hash(String, String), conn = @@conn)
    query = "INSERT OR REPLACE INTO options(cluster_id, volume_id, name, value, created_at, updated_at) VALUES"

    values = [] of String
    params = [] of DB::Any
    opts.each do |name, value|
      values << "(?,          ?,         ?,   ?,     datetime(), datetime())"
      params << cluster_id
      params << volume_id
      params << name
      params << value
    end

    conn.not_nil!.exec(
      "#{query} #{values.join(",")}",
      args: params
    )
  end

  def self.create_option(cluster_id : String, volume_id : String, name : String, value : String, conn = @@conn)
    query = "INSERT OR REPLACE INTO options(cluster_id, volume_id, name, value, created_at, updated_at)
             VALUES                        (?,          ?,         ?,   ?,     datetime(), datetime())"

    conn.not_nil!.exec(
      query,
      cluster_id,
      volume_id,
      name,
      value
    )
  end

  def self.delete_option(volume_id : String, names : Array(String), conn = @@conn)
    query = "DELETE FROM options WHERE volume_id = ? AND IN "

    values = [volume_id]
    params = [] of DB::Any

    names.each do |name|
      values << "?"
      params << name
    end

    @@conn.not_nil!.exec(
      "#{query} (#{values.join(",")})",
      args: params
    )
  end

  def self.delete_option(volume_id : String, name : String, conn = @@conn)
    query = "DELETE FROM options WHERE volume_id = ? AND name = ?"
    @@conn.not_nil!.exec(query, volume_id, name)
  end
end
