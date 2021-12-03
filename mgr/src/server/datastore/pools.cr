require "uuid"

require "moana_types"

# WORKDIR/
#   - pools/
#       - mypool/
#           - info
module Datastore
  def self.pool_dir(pool_name)
    Path.new(@@rootdir, "pools", pool_name)
  end

  def self.pool_file(pool_name)
    Path.new(pool_dir(pool_name), "info")
  end

  def self.save_pool(pool)
    Dir.mkdir_p(pool_dir(pool.name))
    File.write(pool_file(pool.name), pool.to_json)

    pool
  end

  def self.list_pools
    pools = [] of MoanaTypes::Pool
    pools_dir = Path.new(@@rootdir, "pools")

    return pools unless File.exists?(pools_dir)

    Dir.entries(pools_dir).each do |pool_name|
      if pool_name != "." && pool_name != ".."
        pools << get_pool(pool_name).not_nil!
      end
    end

    pools
  end

  def self.get_pool(pool_name)
    pool_file_path = pool_file(pool_name)
    return nil unless File.exists?(pool_file_path)

    MoanaTypes::Pool.from_json(File.read(pool_file_path).strip)
  end

  def self.create_pool(pool_name)
    pool = get_pool(pool_name)
    return pool unless pool.nil?

    pool_id = UUID.random.to_s
    pool = MoanaTypes::Pool.new
    pool.id = pool_id
    pool.name = pool_name
    save_pool(pool)
  end
end
