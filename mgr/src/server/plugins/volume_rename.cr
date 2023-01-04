require "../datastore/*"

post "/api/v1/pools/:pool_name/volumes/:volume_name/rename" do |env|
  pool_name = env.params.url["pool_name"]
  volume_name = env.params.url["volume_name"]

  new_pool_name = env.params.json["new_pool_name"].as(String)
  new_volname = env.params.json["new_volname"].as(String)

  forbidden_api_exception(!Datastore.maintainer?(env.user_id, pool_name, volume_name))

  pool = Datastore.get_pool(pool_name)
  api_exception(pool.nil?, ({"error": "Pool does not exist."}.to_json))
  pool = pool.not_nil!

  volume = Datastore.get_volume(pool_name, volume_name)
  api_exception(volume.nil?, ({"error": "Volume does not exist."}.to_json))

  volume = volume.not_nil!

  new_pool = Datastore.get_pool(new_pool_name)

  api_exception(new_pool.nil?, ({"error": "Target Pool #{new_pool_name} does not exist."}.to_json))
  new_pool = new_pool.not_nil!

  api_exception(
    Datastore.volume_name_exists_by_pool_id?(new_volname, new_pool.id),
    ({"error": "Volume #{new_volname} already exists in target Pool #{new_pool_name}"}.to_json)
  )

  api_exception(volume.state == "Started", ({"error": "Volume should be stopped before renaming."}.to_json))

  transfer_volume = pool_name != new_pool_name
  if transfer_volume
    api_exception(
      Datastore.node_part_of_other_volume?(pool.id, volume.id),
      ({"error": "Node(s) are part of other volume(s) in the current pool."}.to_json)
    )

    # Update pool_name in .info file at every local_data_nodes
    nodes = participating_nodes(pool_name, volume)
    resp = dispatch_action(
      ACTION_NODE_POOL_RENAME,
      pool_name,
      nodes,
      {"new_pool_name": new_pool_name, "old_pool_name": pool_name}.to_json,
    )

    api_exception(!resp.ok, ({"error": "Failed to rename volume"}.to_json))

    # TODO: Find cmd to pass node_id & update in DB as arr to avoid for loop
    Datastore.update_volume_to_new_pool(new_volname, new_pool.id, volume.id)

    # TOOD: Good First Taks: Move node update step under 'update_volume_to_new_pool'
    nodes.each do |node|
      Datastore.update_node_to_new_pool(node.id, new_pool.id)
    end
  end

  Datastore.rename_volume(pool.id, volume.id, new_volname) unless transfer_volume

  volume.name = new_volname

  env.response.status_code = 200

  volume.to_json
end
