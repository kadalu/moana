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

  def task_route(task_type)
    case task_type
    when "volume_create"
      ["POST", "/api/volumes", 201]
    else
      nil
    end
  end

  def update_task_state(task_id, resp_status, reply)
    response = HTTP::Client.put(
      "#{@moana_url}/api/tasks/#{@cluster_id}/#{@node_id}/#{task_id}",
      body: {"state" => resp_status, "response" => reply}.to_json,
      headers: HTTP::Headers{"Content-Type" => "application/json"}
    )
    if response.status_code != 200
      STDERR.puts "Failed to send response: #{response.status_code}"
    end
  end

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

    update_task_state task.id, RECEIVED, "{}"
    
    method, url, expected_status = router_data

    case method
    when "POST"
      response = HTTP::Client.post(
        "#{@endpoint}#{url}",
        body: task.to_json,
        headers: HTTP::Headers{"Content-Type" => "application/json"}
      )
    end

    if !response.nil?
      puts response.status_code
      resp_status = SUCCESS
      if response.status_code != expected_status
        resp_status = FAILURE
      end

      update_task_state task.id, resp_status, response.body
    end
  end

  def get_messages
    url = "#{@moana_url}/api/tasks/#{@cluster_id}/#{@node_id}"
    begin
      response = HTTP::Client.get url
    rescue Socket::ConnectError
      STDERR.puts "Moana Server is not reachable. Waiting..."
      sleep 5.seconds
      return
    end

    if response.status_code == 200
      tasks = Array(Task).from_json(response.body)
      tasks.each do |task|
        handle_task task
      end
    end
    sleep 5.seconds
  end

  def start()
    spawn do
      loop do
        get_messages
      end
    end
  end
end
