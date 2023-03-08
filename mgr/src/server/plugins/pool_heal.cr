require "file_utils"
require "xml"

struct HealStorageUnit
  include JSON::Serializable

  property id = "", name = "", status = "", heal_total : Int64 = 0,
    heal_pending_count : Int64 = 0, heal_split_brain_count : Int64 = 0,
    heal_possibly_healing_count : Int64 = 0, heal_pending_files = [] of Tuple(String, String)

  def initialize
  end
end

def parse_heal_data(document)
  bricks = document.xpath_nodes("//bricks")
  brick_data = Hash(String, HealStorageUnit).new

  bricks.map do |bk|
    brick = HealStorageUnit.new
    bk.children.each do |ele|
      next unless ele.name == "brick"
      next unless ele["hostUuid"] != "-"

      brick.id = ele["hostUuid"].strip
      brick.heal_pending_files.clear

      brick.heal_total = 0
      brick.heal_pending_count = 0
      brick.heal_split_brain_count = 0
      brick.heal_possibly_healing_count = 0

      ele.children.each do |ele_child|
        case ele_child.name
        when "name"
          brick.name = ele_child.content.strip
        when "status"
          brick.status = ele_child.content.strip
        when "file"
          brick.heal_pending_files << {ele_child["gfid"], ele_child.content.strip}
        when "totalNumberOfEntries"
          brick.heal_total = ele_child.content.strip.to_i64
        when "numberOfEntries"
          brick.heal_total = ele_child.content.strip.to_i64
        when "numberOfEntriesInHealPending"
          brick.heal_pending_count = ele_child.content.strip.to_i64
        when "numberOfEntriesInSplitBrain"
          brick.heal_split_brain_count = ele_child.content.strip.to_i64
        when "numberOfEntriesPossiblyHealing"
          brick.heal_possibly_healing_count = ele_child.content.strip.to_i64
        end
      end
      brick_data[brick.name] = brick
    end
  end

  brick_data
end

def set_heal_data(pool, brick_data)
  pool.distribute_groups.each do |dist_grp|
    dist_grp.storage_units.each do |storage_unit|
      storage_unit_full_path = storage_unit.node.name + ":" + storage_unit.path

      heal_storage_unit_data = brick_data[storage_unit_full_path]?
      next if heal_storage_unit_data.nil?

      storage_unit.heal_metrics.heal_status = heal_storage_unit_data.status
      storage_unit.heal_metrics.heal_total = heal_storage_unit_data.heal_total
      storage_unit.heal_metrics.heal_pending_count = heal_storage_unit_data.heal_pending_count
      storage_unit.heal_metrics.heal_split_brain_count = heal_storage_unit_data.heal_split_brain_count
      storage_unit.heal_metrics.heal_possibly_healing_count = heal_storage_unit_data.heal_possibly_healing_count
      storage_unit.heal_metrics.heal_pending_files = heal_storage_unit_data.heal_pending_files
    end
  end

  pool
end

def glfsheal_path
  heal_bin_prefix = "/usr/libexec"
  if File.exists?("/usr/local/libexec/glusterfs/glfsheal")
    heal_bin_prefix = "/usr/local/libexec"
  end
  "#{heal_bin_prefix}/glusterfs/glfsheal"
end

post "/api/v1/pools/:pool_name/heal/start" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))

  pool = pool.not_nil!

  api_exception(!pool.replicate_family?, ({"error": "Cannot heal Pool(#{pool_name}). It is non replicated or dispersed"}.to_json))

  client_volfile = "/var/lib/kadalu/volfiles/client-dev-#{pool_name}.vol"

  if !File.exists?(client_volfile)
    tmpl = volfile_get("client")
    content = Volgen.generate(tmpl, pool.to_json, pool.options)
    Dir.mkdir_p "/var/lib/kadalu/volfiles"
    File.write(client_volfile, content)
  end

  rc, output, err = execute(glfsheal_path, [pool_name, "--xml", "volfile-path", client_volfile])

  api_exception(rc < 0, ({"error": err}.to_json))

  document = XML.parse(output)

  storage_unit_data = parse_heal_data(document)
  out_pool = set_heal_data(pool, storage_unit_data)

  env.response.status_code = 200
  out_pool.to_json
end

get "/api/v1/pools/:pool_name/heal" do |env|
  pool_name = env.params.url["pool_name"]

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))

  pool = pool.not_nil!

  api_exception(
    !pool.replicate_family?,
    ({"error": "Cannot heal Pool(#{pool_name}). It is non replicated or dispersed"}.to_json)
  )

  client_volfile = "/var/lib/kadalu/volfiles/client-dev-#{pool_name}.vol"

  if !File.exists?(client_volfile)
    tmpl = volfile_get("client")
    content = Volgen.generate(tmpl, pool.to_json, pool.options)
    Dir.mkdir_p "/var/lib/kadalu/volfiles"
    File.write(client_volfile, content)
  end

  rc, output, err = execute(glfsheal_path, ["vol1", "info-summary", "--xml", "volfile-path", client_volfile])

  api_exception(rc < 0, ({"error": err}.to_json))

  document = XML.parse(output)

  brick_data = parse_heal_data(document)
  pool = set_heal_data(pool, brick_data)

  env.response.status_code = 200
  pool.to_json
end
