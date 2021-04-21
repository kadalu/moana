require "./helpers"

struct TaskError
  include JSON::Serializable

  property error : String, status_code : Int32, node : MoanaTypes::Node
end

struct TaskListCommand < Command
  def handle
    cluster_id = cluster_id_from_name(@args.cluster.name)
    client = moana_client(@gflags.kadalu_mgmt_server)
    cluster = client.cluster(cluster_id)
    begin
      # TODO: Show summary of the task from task.data
      if @args.task.id != ""
        task = cluster.task(@args.task.id).get

        puts "Task ID: #{task.id}"
        puts "State: #{task.state}"
        puts "Assigned To: #{task.node.hostname}"
        puts "Type: #{task.type}"

        if task.state == "Failed"
          puts "Failures:"

          errors = Array(TaskError).from_json(task.response)
          errors.each do |err|
            puts "  Node: #{err.node.hostname} (ID: #{err.node.id})"
            puts "  Status code: #{err.status_code}"
            puts "  Error: #{err.error}"
            puts
          end
        end
      else
        tasks_data = cluster.tasks
        if tasks_data.size > 0
          printf("%-36s  %-10s  %-20s  %-15s\n", "Task ID", "State", "Assigned To", "Type")
        end
        tasks_data.each do |task|
          printf("%-36s  %-10s  %-20s  %-15s\n",
            task.id,
            task.state,
            task.node.hostname,
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
