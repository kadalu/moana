require "./spec_helper"

def node_hash
  {"hostname" => "Fake", "endpoint" => "Fake"}
end

def node_params
  params = [] of String
  params << "hostname=#{node_hash["hostname"]}"
  params << "endpoint=#{node_hash["endpoint"]}"
  params.join("&")
end

def create_node
  model = Node.new(node_hash)
  model.save
  model
end

class NodeControllerTest < GarnetSpec::Controller::Test
  getter handler : Amber::Pipe::Pipeline

  def initialize
    @handler = Amber::Pipe::Pipeline.new
    @handler.build :api do
      plug Amber::Pipe::Error.new
      plug Amber::Pipe::Session.new
    end
    @handler.prepare_pipelines
  end
end

describe NodeControllerTest do
  subject = NodeControllerTest.new

  it "renders node index json" do
    Node.clear
    model = create_node
    response = subject.get "/nodes"

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "renders node show json" do
    Node.clear
    model = create_node
    location = "/nodes/#{model.id}"

    response = subject.get location

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "creates a node" do
    Node.clear
    response = subject.post "/nodes", body: node_params

    response.status_code.should eq(201)
    response.body.should contain "Fake"
  end

  it "updates a node" do
    Node.clear
    model = create_node
    response = subject.patch "/nodes/#{model.id}", body: node_params

    response.status_code.should eq(200)
    response.body.should contain "Fake"
  end

  it "deletes a node" do
    Node.clear
    model = create_node
    response = subject.delete "/nodes/#{model.id}"

    response.status_code.should eq(204)
  end
end
