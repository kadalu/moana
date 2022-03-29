require "moana_types"

require "../conf"
require "./helpers"
require "../datastore/*"
require "./ping"
require "./volume_utils.cr"

# POST /api/v1/pools/:pool_id/volumes/:volume_id/options/set
post "/api/v1/pools/:pool_name/volumes/:volume_name/options/set" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  puts pool_name

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  # move this after validations:::
  # puts (env.params.json.fetch("volume_options", "").as(String))
  # puts (env.params.body["volume_options"])
  volume_options = env.params.json["volume_options"].as(String)
  # name2 = env.params.body["volume_options"].as(String)

  puts volume_options
  puts typeof(volume_options)
  # puts name2

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  puts "in here"
  puts typeof(volume.options)
  puts volume.options

  volume.options = volume.options.merge(Hash(String, String).from_json(volume_options))
  puts volume.options

  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options.to_json.to_s)

  volume = Datastore.get_volume(pool_name, volume_name)
  puts volume.to_pretty_json

  env.response.status_code = 201
  volume.to_json
end

# POST /api/v1/pools/:pool_id/volumes/:volume_id/options/reset
post "/api/v1/pools/:pool_name/volumes/:volume_name/options/reset" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  puts pool_name

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  # move this after validations:::
  volume_option_keys = env.params.json["volume_option_keys"].as(Array)

  puts volume_option_keys
  puts typeof(volume_option_keys)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  volume.options = volume.options.reject(volume_option_keys)
  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options.to_json.to_s)

  volume = Datastore.get_volume(pool_name, volume_name)
  puts volume.to_pretty_json

  env.response.status_code = 201
  volume.to_json
end
