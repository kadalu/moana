require "json"
require "http/client"

QUEUED = "Queued"
RECEIVED = "Received"
SUCCESS = "Success"
FAILURE = "Failure"

class Task
  include JSON::Serializable

  property id : String
  property data : String
  property state : String
  property type : String
  property response : String
end

class Watcher
  def initialize(@moana_url : String, @cluster_id : String, @node_id : String, @endpoint : String)
  end

  # Returns the routes for the supported actions in
  # the format [HTTP_METHOD, URL, EXPECTED_HTTP_STATUS]
  def task_route(task_type)
    case task_type
    when "volume_create"
      ["POST", "/api/volumes", 201]
    else
      nil
    end
  end

  # Update the status of Task, before and after the execution.
  # Queued -> Received -> Success|Failure
  def update_task_state(task_id, resp_status, reply)
    url = "#{@moana_url}/api/tasks/#{@cluster_id}/#{@node_id}/#{task_id}"

    response = HTTP::Client.put(
      url,
      body: {"state" => resp_status, "response" => reply}.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"}
    )

    if response.status_code != 200
      STDERR.puts "Failed to send response: #{response.status_code}"
    end
  end

  # Main entry point for each Task. Decide the router and
  # participating nodes. Then based on the HTTP Method, make
  # ReST API call to those nodes.
  def handle_task(task)
    router_data = task_route task.type
    if router_data.nil?
      STDERR.puts "Unsupported Task Type: #{task.type}"
      return
    end

    # Do not Look again if already processed
    if task.state == SUCCESS && task.state == FAILURE
      return
    end

    # Updating status as RECEIVED helps the users
    # to know that a task is picked up.
    # Also helps to Timeout an action from Server
    update_task_state task.id, RECEIVED, "{}"

    method, url, expected_status = router_data

    case method
    when "POST"
      # TODO: Get list of participating nodes and
      # call the same API with all participating
      # endpoints.
      # TODO: Execute the HTTP calls concurrently
      response = HTTP::Client.post(
        "#{@endpoint}#{url}",
        body: task.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
    end

    if !response.nil?
      resp_status = SUCCESS
      if response.status_code != expected_status
        resp_status = FAILURE
      end

      # Two possible Status: SUCCESS and FAILURE
      update_task_state task.id, resp_status, response.body
    end
  end

  # Entry point to get the list of Tasks from Moana Server
  def start()
    spawn do
      loop do
        # TODO: Remember the last processed entry so that avoid
        # getting same entries again and again.

        url = "#{@moana_url}/api/tasks/#{@cluster_id}/#{@node_id}"

        begin
          response = HTTP::Client.get url
        rescue Socket::ConnectError
          STDERR.puts "Moana Server is not reachable. Waiting..."
          sleep 10.seconds
          return
        end

        if response.status_code == 200
          tasks = Array(Task).from_json(response.body)

          # Execute each action in sequence
          tasks.each do |task|
            handle_task task
          end
        end
        sleep 5.seconds
      end
    end
  end
end
