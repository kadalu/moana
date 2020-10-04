class TaskResponseHandlerException < Exception
end

def task_volume_create(task)
  # TODO: Use Db Transaction to insert all these
  volreq = VolumeRequest.from_json(task.data.not_nil!)
  volume = Volume.new(
    {
      "id" => volreq.id,
      "name" => volreq.name,
      "state" => "Created",
      "type" => volreq.type,
      "replica_count" => volreq.replica_count,
      "disperse_count" => volreq.disperse_count
    }
  )

  volume.cluster = Cluster.new(
    {
      "id" => volreq.cluster_id
    }
  )

  if !volume.save
    raise TaskResponseHandlerException.new("failed to save volume")
  end

  volreq.bricks.each do |brickreq|
    brick = Brick.new(
      {
        "path" => brickreq.path == "" ? "-" : brickreq.path,
        "device" => brickreq.device == "" ? "-" : brickreq.device,
        "port" => brickreq.port,
        "state" => "-"
      }
    )
    brick.cluster = volume.cluster

    brick.volume = volume
    if node = brickreq.node
      brick.node = Node.new(
        {
          "id" => node.id
        }
      )
    end
    if !brick.save
      raise TaskResponseHandlerException.new("failed to save brick details")
    end
  end
end


def task_volume_start(task)
  voldata = VolumeResponse.from_json(task.data.not_nil!)
  volume = Volume.find(voldata.id)
  if volume
    volume.state = "Started"
    if !volume.save
      raise TaskResponseHandlerException.new("failed to update volume state to Started")
    end
  else
    raise TaskResponseHandlerException.new("failed to find volume to update the state")
  end
end

def task_volume_stop(task)
  voldata = VolumeResponse.from_json(task.data.not_nil!)
  volume = Volume.find(voldata.id)
  if volume
    volume.state = "Stopped"
    if !volume.save
      raise TaskResponseHandlerException.new("failed to update volume state to Stopped")
    end
  else
    raise TaskResponseHandlerException.new("failed to find volume to update the state")
  end
end
