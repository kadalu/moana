require "http/web_socket"
require "json"

module ConnectionManager
  @@manager = Manager.new

  def self.manager
    @@manager
  end

  class TimeoutException < Exception
    property responses

    def initialize(@message : String, @responses : Hash(String, Message))
      super(@message)
    end
  end

  class NotOnlineException < Exception
    property responses, ids

    def initialize(@message : String, @ids : Array(String), @responses : Hash(String, Message))
      super(@message)
    end
  end

  class Message
    include JSON::Serializable

    property id = "", message = "", response = "", type = "task", task_done = true

    def initialize(@id, @message)
    end
  end

  class Namespace
    property connections = Hash(String, HTTP::WebSocket).new,
      tasks = Hash(String, Hash(String, Message)).new
  end

  class Manager
    private record AddConnection, namespace : String, id : String, socket : HTTP::WebSocket
    private record CloseConnection, namespace : String, id : String
    private record ListNamespaces, return_channel : Channel(Array(String))
    private record ListConnections, namespace : String, ids : Array(String), return_channel : Channel(Hash(String, HTTP::WebSocket))
    private record GetConnectionState, namespace : String, id : String, return_channel : Channel(Bool)

    private record AddTaskResponse, namespace : String, task : Message, id : String
    private record AddTask, namespace : String, task_id : String
    private record GetTaskResponses, namespace : String, task_id : String, return_channel : Channel(Hash(String, Message))
    private record TaskDone, namespace : String, task_id : String
    private record SendMessage, namespace : String, id : String, message : String

    @requests = Channel(AddConnection | CloseConnection | ListConnections |
                        AddTaskResponse | AddTask | ListNamespaces | GetConnectionState |
                        GetTaskResponses | TaskDone | SendMessage).new

    def handle_add_connection(command)
      if !@namespaces[command.namespace]?
        @namespaces[command.namespace] = Namespace.new
      end

      @namespaces[command.namespace].connections[command.id] = command.socket
    end

    def handle_close_connection(command)
      @namespaces[command.namespace].connections.delete(command.id)

      if @namespaces[command.namespace].connections.size == 0
        @namespaces.delete(command.namespace)
      end
    end

    def handle_list_namespaces(command)
      command.return_channel.send @namespaces.keys
    end

    def handle_list_connections(command)
      connections = Hash(String, HTTP::WebSocket).new

      if @namespaces[command.namespace]?
        if command.ids.size == 0
          connections = @namespaces[command.namespace].connections
        else
          connections = @namespaces[command.namespace].connections.select(command.ids)
        end
      end
      command.return_channel.send connections
    end

    def handle_add_task_response(command)
      if @namespaces[command.namespace].tasks[command.task.id]?
        @namespaces[command.namespace].tasks[command.task.id][command.id] = command.task
      end
    end

    def handle_add_task(command)
      if @namespaces[command.namespace]?
        @namespaces[command.namespace].tasks[command.task_id] = Hash(String, Message).new
      end
    end

    def handle_get_connection_state(command)
      connected = false
      if @namespaces[command.namespace]? && @namespaces[command.namespace].connections[command.id]?
        connected = true
      end
      command.return_channel.send connected
    end

    def handle_get_task_responses(command)
      command.return_channel.send(
        if !@namespaces[command.namespace]? || !@namespaces[command.namespace].tasks[command.task_id]?
          Hash(String, Message).new
        else
          @namespaces[command.namespace].tasks[command.task_id]
        end
      )
    end

    def handle_task_done(command)
      if @namespaces[command.namespace]?
        @namespaces[command.namespace].tasks.delete(command.task_id)
      end
    end

    def handle_send_message(command)
      if @namespaces[command.namespace]? && @namespaces[command.namespace].connections[command.id]?
        @namespaces[command.namespace].connections[command.id].send command.message
      end
    end

    def initialize
      @namespaces = Hash(String, Namespace).new

      spawn(name: "task_manager") do
        loop do
          {% begin %}
            case command = @requests.receive
                {% for value in Manager.constants %}
                when {{ value }}
                  handle_{{ value.underscore }}(command)
                {% end %}
            end
          {% end %}
        end
      end
    end

    def add_task_response(namespace, task, id)
      @requests.send AddTaskResponse.new(namespace, task, id)
    end

    def task_responses(namespace, task_id)
      Channel(Hash(String, Message)).new.tap { |return_channel|
        @requests.send GetTaskResponses.new(namespace, task_id, return_channel)
      }.receive
    end

    def add_connection(namespace, id, socket)
      @requests.send AddConnection.new(namespace, id, socket)
    end

    def close_connection(namespace, id)
      @requests.send CloseConnection.new(namespace, id)
    end

    def list_namespaces
      Channel(Array(String)).new.tap { |return_channel|
        @requests.send ListNamespaces.new(return_channel)
      }.receive
    end

    def list_connections(namespace, ids)
      Channel(Hash(String, HTTP::WebSocket)).new.tap { |return_channel|
        @requests.send ListConnections.new(namespace, ids, return_channel)
      }.receive
    end

    def list_connections(namespace)
      list_connections(namespace, [] of String)
    end

    def connected?(namespace, id)
      Channel(Bool).new.tap { |return_channel|
        @requests.send GetConnectionState.new(namespace, id, return_channel)
      }.receive
    end

    def task(namespace, task, participants, partial = false, timeout = 0)
      @requests.send AddTask.new(namespace, task.id)

      start_time = Time.monotonic
      conns = list_connections(namespace, participants)
      connected_ids = conns.keys
      disconnected_ids = participants.select { |id| !conns[id]? }
      if !partial && disconnected_ids.size > 0
        raise NotOnlineException.new(
          "Not all required participants are connected.",
          disconnected_ids,
          task_responses(namespace, task.id)
        )
      end

      # Try sending message to each connected sockets
      # TODO: Handle failure
      conns.each do |id, _|
        @requests.send SendMessage.new(namespace, id, task.to_json)
      end

      loop do
        # Success. Task Response received from all the participating nodes
        break if participants.size == task_responses(namespace, task.id).size

        conns = list_connections(namespace, participants)
        connected_ids = conns.keys
        disconnected_ids = participants.select { |id| !conns[id]? }

        # If partial == true, then task response received
        # from all the connected connections
        break if partial && connected_ids.size == task_responses(namespace, task.id).size

        if !partial && disconnected_ids.size > 0
          raise NotOnlineException.new(
            "A few or all participants disconnected after the task is assigned.",
            disconnected_ids,
            task_responses(namespace, task.id)
          )
        end

        if timeout > 0
          t2 = Time.monotonic
          if (t2 - start_time) > timeout.seconds
            raise TimeoutException.new("Timed out", task_responses(namespace, task.id))
          end
        end

        sleep 1.seconds
      end

      begin
        task_responses(namespace, task.id)
      ensure
        @requests.send TaskDone.new(namespace, task.id)
      end
    end

    # def task(namespace, task, partial=false, timeout=0)
    #   task(namespace, task, [] of String, partial, timeout)
    # end

    def message(namespace, message, participants, partial = false)
      conns = list_connections(namespace, participants)
      disconnected_ids = participants.select { |id| !conns[id]? }

      if !partial && disconnected_ids.size > 0
        raise NotOnlineException.new(
          "Not all required participants are connected.",
          disconnected_ids,
          task_responses(namespace, task.id)
        )
      end

      # Try sending message to each connected sockets
      # TODO: Handle failure
      conns.each do |id, _|
        @requests.send SendMessage.new(namespace, id, message)
      end
    end

    def message(namespace, message, partial = false)
      message(namespace, message, [] of String, partial)
    end
  end
end
