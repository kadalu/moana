def show_tasks(gflags, args)
  cluster_id = cluster_id_from_name(args.cluster_name)
  client = MoanaClient::Client.new(gflags.moana_url)
  cluster = client.cluster(cluster_id)
  begin
    if args.task_id != ""
      tasks_data = [cluster.task(args.task_id).get]
    else
      tasks_data = cluster.tasks
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
  rescue ex : MoanaClient::MoanaClientException
    STDERR.puts ex.status_code
    exit 1
  end
end
