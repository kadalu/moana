class Task
  include JSON::Serializable

  property id : String,
           type : String?,
           state : String?,
           node : Node?
end

def show_tasks(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  url = "#{gflags.moana_url}/api/clusters/#{cluster_id}/tasks"
  if args.task_id != ""
    url = "#{url}/{args.task_id}"
  end
  response = HTTP::Client.get url
  content = "[]"
  if response.status_code == 200
    content = response.body
  else
    STDERR.puts response.status_code
    exit 1
  end
  if args.task_id != ""
    tasks_data = [Task.from_json(content)]
  else
    tasks_data = Array(Task).from_json(content)
  end

  if tasks_data
    printf("%-36s  %-10s  %-20s  %-15s\n", "Task ID", "State", "Assigned To", "Type")
  end
  tasks_data.each do |task|
    hostname = ""
    if node = task.node
      node_id = node.id
      hostname = node.hostname
    end
    printf("%-36s  %-10s  %-20s  %-15s\n",
           task.id,
           task.state,
           hostname,
           task.type)
  end
end
