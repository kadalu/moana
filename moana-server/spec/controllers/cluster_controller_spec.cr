require "./spec_helper"

def cluster_hash
  {"name" => "Fake"}
end

def cluster_params
  params = [] of String
  params << "name=#{cluster_hash["name"]}"
  params.join("&")
end

def create_cluster
  model = Cluster.new(cluster_hash)
  model.save
  model
end

class ClusterControllerTest < GarnetSpec::Controller::Test
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

describe ClusterControllerTest do
  subject = ClusterControllerTest.new

  it "renders cluster index json" do
    Cluster.clear
    model = create_cluster
    response = subject.get "/clusters"

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "renders cluster show json" do
    Cluster.clear
    model = create_cluster
    location = "/clusters/#{model.id}"

    response = subject.get location

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "creates a cluster" do
    Cluster.clear
    response = subject.post "/clusters", body: cluster_params

    response.status_code.should eq(201)
    response.body.should contain "Fake"
  end

  it "updates a cluster" do
    Cluster.clear
    model = create_cluster
    response = subject.patch "/clusters/#{model.id}", body: cluster_params

    response.status_code.should eq(200)
    response.body.should contain "Fake"
  end

  it "deletes a cluster" do
    Cluster.clear
    model = create_cluster
    response = subject.delete "/clusters/#{model.id}"

    response.status_code.should eq(204)
  end
end
