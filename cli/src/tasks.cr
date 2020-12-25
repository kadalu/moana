require "./helpers"

struct TaskListArgs < Args
  property task_id : String = ""

  def handle(gflags : Gflags)
    cluster_id = cluster_id_from_name(@cluster_name)
    client = MoanaClient::Client.new(gflags.moana_url)
    cluster = client.cluster(cluster_id)
    begin
      if @task_id != ""
        tasks_data = [cluster.task(@task_id).get]
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
end

class MoanaCommands
  def task_commands(parser)
    parser.on("task", "Manage Tasks") do
      parser.banner = "Usage: moana task <subcommand> [arguments]"
      parser.on("list", "List Tasks") do
        args = TaskListArgs.new
        parser.banner = "Usage: moana node list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| args.cluster_name = name }
        parser.on("-t TASK", "--task-id=TASK", "TASK Id") { |task_id| args.task_id = task_id }

        @args = args
      end
    end
  end
end

