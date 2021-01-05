require "kemal"

require "./db/*"
require "./helpers"

get "/api/v1/clusters/:cluster_id/volumes/:volume_id/options" do |env|
  if !volume_viewer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  MoanaDB.list_options(env.params.url["volume_id"]).to_json
end

post "/api/v1/clusters/:cluster_id/volumes/:volume_id/options/set" do |env|
  if !volume_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  req = Hash(String, String).from_json(env.request.body.not_nil!)
  MoanaDB.create_option(env.params.url["cluster_id"], env.params.url["volume_id"], req)
  {ok: true}.to_json
end

post "/api/v1/clusters/:cluster_id/volumes/:volume_id/options/reset" do |env|
  if !volume_maintainer?(env)
    halt(env, status_code: 403, response: forbidden_response)
  end

  req = Array(String).from_json(env.request.body.not_nil!)
  MoanaDB.delete_option(env.params.url["volume_id"], req)
  {ok: true}.to_json
end
