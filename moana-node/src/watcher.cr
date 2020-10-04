require "json"
require "http/client"

require "moana_types"
require "moana_client"

SUPPORTED_TASK_TYPES = ["volume_create", "volume_start"]
QUEUED = "Queued"
RECEIVED = "Received"
SUCCESS = "Success"
FAILURE = "Failure"

class Watcher
  def initialize()
    @moana_url = ""
    @cluster_id = ""
    @node_id = ""
  end

  def participating_nodes(task)
    case task.type
    when "volume_create"
      volreq = MoanaTypes::VolumeRequest.from_json(task.data)

      volreq.bricks.map do |brick|
        brick.node
      end

    else
      [] of MoanaTypes::NodeRequest
    end

  end

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

  # Main entry point for each Task. Decide the router and
  # participating nodes. Then based on the HTTP Method, make
  # ReST API call to those nodes.
  def handle_task(task)
    if !SUPPORTED_TASK_TYPES.includes?(task.type)
      STDERR.puts "Unsupported Task Type: #{task.type}"
      return
    end

    # Do not Look again if already processed
    if task.state == SUCCESS || task.state == FAILURE
      return
    end

    # Updating status as RECEIVED helps the users
    # to know that a task is picked up.
    # Also helps to Timeout an action from Server
    update_task_state task.id, RECEIVED, "{}"

    errors = [] of Hash(String, Int32 | MoanaTypes::NodeRequest | String)

    # TODO: Execute the HTTP calls concurrently
    nodes = participating_nodes task
    nodes.each do |node|
      begin
        # All task handlers are POST /api/<task_type>
        # and returns 200 as Response.
        response = HTTP::Client.post(
          "#{node.endpoint}/api/#{task.type}",
          body: task.to_json,
          headers: HTTP::Headers{"Content-Type" => "application/json"}
        )
        if response.status_code != 200
          errors << {
            "error" => response.body,
            "node" => node,
            "error_code" => response.status_code
          }
        end
      rescue Socket::ConnectError
        errors << {
          "error" => "connection refused",
          "node" => node,
          "error_code" => 0
        }
      end
    end

    resp_status = SUCCESS
    if errors.size > 0
      resp_status = FAILURE
    end

    # Two possible Status: SUCCESS and FAILURE
    update_task_state task.id, resp_status, errors.to_json
  end

  # Entry point to get the list of Tasks from Moana Server
  def start()
    spawn do
      # Wait for Moana node HTTP server comes online
      sleep 10.seconds

      # Open and see the Node config file
      workdir = ENV.fetch("WORKDIR", "")
      node_conf = NodeConfig.new(workdir, ENV["NODENAME"])
      loop do
        if node_conf.exists?
          # TODO: Handle JSON error if any failure
          conf = node_conf.get
          # Node is joined to a Cluster, set required
          # instance variables
          @node_id = conf.node_id
          @moana_url = conf.moana_url
          @cluster_id = conf.cluster_id
          break
        else
          # Node is not yet Joined to a Cluster
          sleep 10.seconds
        end
      end

      client = MoanaClient::Client.new(@moana_url)
      node = client.cluster(@cluster_id).node(@node_id)

      loop do
        # TODO: Remember the last processed entry so that avoid
        # getting same entries again and again.

        begin
          # Execute each action in sequence
          node.tasks.each do |task|
            handle_task task
          end
        rescue Socket::ConnectError
          STDERR.puts "Moana Server is not reachable. Waiting..."
          sleep 10.seconds
          next
        rescue ex : MoanaClient::MoanaClientException
          STDERR.puts "Failed to get tasks from Moana Server(HTTP Error #{ex.status_code})"
        end

        sleep 5.seconds
      end
    end
  end
end
