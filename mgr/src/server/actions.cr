require "json"
require "http/client"

require "./datastore/*"

struct NodeResponse
  include JSON::Serializable

  property ok = false, response = "", status_code = 200

  def initialize(@ok, @response)
  end
end

struct Response
  include JSON::Serializable

  property ok = true, node_responses = Hash(String, NodeResponse).new

  def initialize
  end

  def set_node_response(node, resp)
    @node_responses[node] = resp
    @ok = false if !resp.ok
  end
end

module Action
  @@actions = Hash(String, (String -> NodeResponse)).new

  def self.add(name, &block : String -> NodeResponse)
    @@actions[name] = block
  end

  def self.run(name, data)
    @@actions[name].call(data)
  end

  def self.dispatch(name : String, pool_name : String, nodes : Array(MoanaTypes::Node), data : String)
    headers = HTTP::Headers.new
    headers["Content-Type"] = "application/json"
    resp = Response.new
    # TODO: Send requests concurrently and handle
    # the response

    tokens = Datastore.node_tokens(nodes)
    nodes.each do |node|
      headers["Authorization"] = "Bearer #{node.token}"
      puts "name: #{node.name}, token:#{node.token}"
      STDERR.puts "HELLO from dispatch action"
      url = "#{node.endpoint}/_api/v1/#{name}"
      begin
        node_resp = HTTP::Client.post(url, body: {"data": data}.to_json, headers: headers)
        resp.set_node_response(
          node.id == "" ? node.name : node.id,
          NodeResponse.from_json(node_resp.body)
        )
      rescue Socket::ConnectError
        resp.set_node_response(
          node.id == "" ? node.name : node.id,
          NodeResponse.new(false, {"error": "Node is not reachable"}.to_json)
        )
      end
    end

    resp
  end
end
