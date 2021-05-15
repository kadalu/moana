require "connection_manager"

require "./node_conf"
require "./task/*"

class Watcher
  def initialize(@node_conf : NodeConf)
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

    # TODO: Handle connection failures
    client = HTTP::WebSocket.new(
      URI.parse("#{ws_url}/ws/#{@node_conf.cluster_id}"),
      headers = HTTP::Headers{
        "X-Node-ID"     => @node_conf.node_id,
        "Authorization" => "Bearer #{@node_conf.token}",
      }
    )
    client.on_message do |msg|
      message = ConnectionManager::Message.from_json(msg)
      if message.type == "task"
        # Below code will deserialize into different Task subtypes
        # using JSON discriminator feature.
        # https://crystal-lang.org/api/0.35.1/JSON/Serializable.html#use_json_discriminator(field,mapping)-macro
        task = Task.from_json(message.message)

        begin
          task.run(NodeConf.from_conf)
          message.response = {"ok": true}.to_json
        rescue ex : Exception
          message.task_done = false
          message.response = {"error": ex.message}.to_json
        end

        # TODO: Handle Broken Pipe errors
        client.send message.to_json
      else
        # TODO: Handle one way messages like Reconfigure
        puts "Message received from Server #{message.message}"
      end
    end

    # TODO: Handle any other errors with the connection
    client.run
  end
end
