class Watcher
  # Update the status of Task, before and after the execution.
  # Queued -> Received -> Success|Failure
  def update_task_state(task_id, resp_status, reply)
    client = MoanaClient::Client.new(@moana_url)
    task = client.cluster(@cluster_id).task(task_id)
    begin
      task.update(resp_status, reply)
    rescue ex : MoanaClient::MoanaClientException
      STDERR.puts "Failed to send response: #{ex.status_code}"
    end
  end
  
  def handle_task(client, task)
    if !SUPPORTED_TASK_TYPES.includes?(task.type)
      STDERR.puts "Unsupported Task Type: #{task.type}"
      return
    end

    # Do not Look again if already processed
    if task.state == TASK_STATE_COMPLETED || task.state == TASK_STATE_FAILED
      return
    end

    # Updating status as RECEIVED helps the users
    # to know that a task is picked up.
    # Also helps to Timeout an action from Server
    update_task_state(task.id, TASK_STATUS_RECEIVED, "{}")

    errors = [] of TaskError

    # TODO: Execute the HTTP calls concurrently
    nodes = task.participating_nodes

    nodes.each do |node|
      begin
        # All task handlers are POST /api/<task_type>
        # and returns 200 as Response.
        response = HTTP::Client.post(
          "#{node.endpoint}/api/v1/#{task.type}",
          body: task.to_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"}
        )
        if response.status_code != 200
          node_error = ApiError.from_json(response.body)
          errors << TaskError.new(node_error.error, node, response.status_code)
        end
      rescue Socket::ConnectError
        errors << TaskError.new("connection refused", node, -1)
      end
    end

    resp_status = TASK_STATUS_COMPLETED
    if errors.size > 0
      resp_status = TASK_STATUS_FAILED
    end

    # Two possible Status: TASK_STATE_COMPLETED and TASK_STATE_FAILED
    update_task_state(task.id, resp_status, errors.to_json)
  end

  def start
    # Start watching for Node configuration. When
    # a node joins a Cluster, then a config file is
    # generated and saved in a specific directory.
    # If Config file not exists, then that means Moana
    # node agent is started but no Join request is received.
    workdir = ENV.fetch("WORKDIR", "")
    @node_conf = NodeConfig.new(workdir, ENV["NODENAME"])
    @node_conf.wait()

    # Initialize a Client that connects to Moana Server.
    # Moana Server URL is received from the Configuration
    # file.
    client = MoanaClient::Client.new(@node_conf.moana_url).cluster(@node_conf.cluster_id)
    node = client.node(@node_conf.node_id)

    loop do
      # Now get the list of latest tasks from Moana Server
      # that are assigned to this node. Execute each action in
      # sequence. If Moana Server is not reachable or any API
      # errors to get the list of tasks then wait for some time.
      begin
        # TODO: Remember last task time
        node.latest_tasks().each do |task|
          handle_task(client, task)
        end
      rescue Socket::ConnectError
        STDERR.puts "Moana Server is not reachable. Waiting..."
        sleep 10.seconds
        next
      rescue ex : MoanaClient::MoanaClientException
        STDERR.puts "Failed to get tasks from Moana Server(HTTP Error #{ex.status_code})"
        sleep 10.seconds
        next
      end

      sleep 5.seconds
    end
  end
end
