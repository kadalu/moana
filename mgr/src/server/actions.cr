require "json"
require "http/client"

require "./datastore/*"

struct NodeResponse
  include JSON::Serializable

  property ok = false, response = "", status_code = 200

  def initialize(@ok, @response)
  end

  def initialize(@ok, @response, @status_code)
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
  @@actions = Hash(String, (String, HTTP::Server::Context -> NodeResponse)).new

  def self.add(name, &block : String, HTTP::Server::Context -> NodeResponse)
    @@actions[name] = block
  end

  def self.run(name, data, env)
    @@actions[name].call(data, env)
  end

  def self.dispatch(name : String, nodes : Array(MoanaTypes::Node), data : String)
    headers = HTTP::Headers.new
    headers["Content-Type"] = "application/json"
    resp = Response.new
    # TODO: Send requests concurrently and handle
    # the response

    # Add tokens to nodes[execpt for new additions] for authorization.
    nodes = Datastore.node_tokens(nodes)

    nodes.each do |node|
      headers["Authorization"] = "Bearer #{node.token}"
      url = "#{node.endpoint}/_api/v1/#{name}"
      begin
        node_resp = HTTP::Client.post(url, body: {"data": data}.to_json, headers: headers)
        resp.set_node_response(
          node.name,
          NodeResponse.from_json(node_resp.body)
        )
      rescue Socket::ConnectError
        resp.set_node_response(
          node.name,
          NodeResponse.new(false, {"error": "Node is not reachable"}.to_json)
        )
      rescue Socket::Addrinfo::Error
        resp.set_node_response(
          node.name,
          NodeResponse.new(false, {"error": "Hostname lookup failed for node #{node.name}"}.to_json)
        )
      end
    end

    resp
  end
end
