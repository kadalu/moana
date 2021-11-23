require "connection_manager"

require "./node_conf"
require "./task/*"

class Watcher
  def initialize(@node_conf : NodeConf)
    @connected_notify = false
    @disconnected_notify = false
  end

  def connected_log
    if !@connected_notify
      Log.info { "Connected to Kadalu Storage Server" }
      @connected_notify = true
      # Reset for future notification
      @disconnected_notify = false
    end
  end

  def disconnected_log
    if !@disconnected_notify
      if !@connected_notify
        # First connection failure
        Log.info { "Kadalu Storage Server is not reachable. Retrying.." }
      else
        Log.info { "Disconnected from Server. Reconnecting.." }
      end

      @disconnected_notify = true
      # Reset for future notification
      @connected_notify = false
    end
  end

  def start
    # Start watching for Node configuration. When
    # a node joins a Cluster, then a config file is
    # generated and saved in a specific directory.
    # If Config file not exists, then that means Moana
    # node agent is started but no Join request is received.
    @node_conf.wait

    # Initialize the Websocket connection with the Server
    # to receive tasks and messages
    ws_url = @node_conf.moana_url.gsub("http", "ws")

    loop do
      # TODO: Handle connection failures
      begin
        client = HTTP::WebSocket.new(
          URI.parse("#{ws_url}/ws/#{@node_conf.cluster_id}"),
          headers: HTTP::Headers{
            "X-Node-ID"     => @node_conf.node_id,
            "Authorization" => "Bearer #{@node_conf.token}",
          }
        )

        connected_log
      rescue Socket::ConnectError
        disconnected_log
        sleep @node_conf.connection_retry_interval.seconds
        next
      end

      client.on_message do |msg|
        message = ConnectionManager::Message.from_json(msg)
        if message.type == "task"
          # Below code will deserialize into different Task subtypes
          # using JSON discriminator feature.
          # https://crystal-lang.org/api/0.35.1/JSON/Serializable.html#use_json_discriminator(field,mapping)-macro
          task = NodeTask.from_json(message.message)
          Log.info { "Task received from the server.  type=\"#{task.type}\" id=\"#{task.id}\"" }
          begin
            task.run(NodeConf.from_conf)
            message.response = {"ok": true}.to_json
          rescue ex : Exception
            message.task_done = false
            message.response = {"error": ex.message}.to_json
          end

          begin
            client.send message.to_json
          rescue IO::Error
            disconnected_log
            sleep @node_conf.connection_retry_interval.seconds
            next
          end
        else
          # TODO: Handle one way messages like Reconfigure
          puts "Message received from Server #{message.message}"
        end
      end

      client.run
      disconnected_log
      sleep @node_conf.connection_retry_interval.seconds
    end
  end
end
