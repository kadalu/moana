require "json"
require "http/client"

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

  def self.dispatch(name : String, cluster_name : String, nodes : Array(MoanaTypes::Node), data : String)
    # TODO Set token
    headers = HTTP::Headers.new
    headers["Content-Type"] = "application/json"
    resp = Response.new
    # TODO: Send requests concurrently and handle
    # the response
    nodes.each do |node|
      url = "#{node.endpoint}/_apis/v1/#{name}"
      node_resp = HTTP::Client.post(url, body: {"data": data}.to_json, headers: headers)
      resp.set_node_response(
        node.name,
        NodeResponse.from_json(node_resp.body)
      )
    end

    resp
  end

  def self.dispatch(name : String, cluster_name : String, endpoint : String, data : String)
  end
end
