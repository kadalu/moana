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

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  volume_options = Hash(String, String).from_json(env.request.body.not_nil!)
  volume.options = volume.options.merge(volume_options)

  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options)

  volume = Datastore.get_volume(pool_name, volume_name)
  env.response.status_code = 201
  volume.to_json
end

# POST /api/v1/pools/:pool_id/volumes/:volume_id/options/reset
post "/api/v1/pools/:pool_name/volumes/:volume_name/options/reset" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  next forbidden(env) unless Datastore.maintainer?(env.user_id, pool_name)

  pool = Datastore.get_pool(pool_name)
  if pool.nil?
    halt(env, status_code: 400, response: ({"error": "The Pool(#{pool_name}) doesn't exists"}.to_json))
  end

  volume = Datastore.get_volume(pool_name, volume_name)
  if volume.nil?
    halt(env, status_code: 400, response: ({"error": "The Volume(#{volume_name}) doesn't exists"}.to_json))
  end

  volume_option_keys = Array(String).from_json(env.request.body.not_nil!)
  volume.options = volume.options.reject(volume_option_keys)

  # update volume options to DB.
  Datastore.update_volume_options(volume.id, volume.options)

  volume = Datastore.get_volume(pool_name, volume_name)
  env.response.status_code = 201
  volume.to_json
end
