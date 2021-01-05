require "./helpers"

struct TaskListCommand < Command
  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      if @args.task.id != ""
        tasks_data = [cluster.task(@args.task.id).get]
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
    parser.on("task", "Manage #{PRODUCT} Tasks") do
      @command_type = CommandType::TaskList
      parser.banner = "Usage: #{COMMAND} task <subcommand> [arguments]"
      parser.on("list", "List Tasks") do
        parser.banner = "Usage: #{COMMAND} task list [arguments]"
        parser.on("-c NAME", "--cluster=NAME", "Cluster name") { |name| @args.cluster.name = name }
        parser.on("-t TASK", "--task-id=TASK", "TASK Id") { |task_id| @args.task.id = task_id }
      end
    end
  end
end

