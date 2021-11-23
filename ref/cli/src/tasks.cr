require "./helpers"

struct TaskListCommand < Command
  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      # TODO: Show summary of the task from task.data
      if @args.task.id != ""
        show_task_detail(cluster, @args.task.id)
      else
        tasks_data = cluster.tasks
        if tasks_data.size > 0
          printf("%-36s  %-10s  %-15s\n", "Task ID", "State", "Type")
        end
        tasks_data.each do |task|
          printf("%-36s  %-10s  %-15s\n",
            task.id,
            task.state,
            task.type
          )
        end
      end
    rescue ex : MoanaClient::MoanaClientException
      handle_moana_client_exception(ex)
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
