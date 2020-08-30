require "./spec_helper"

def brick_hash
  {"path" => "Fake", "device" => "Fake", "port" => "1", "state" => "Fake"}
end

def brick_params
  params = [] of String
  params << "path=#{brick_hash["path"]}"
  params << "device=#{brick_hash["device"]}"
  params << "port=#{brick_hash["port"]}"
  params << "state=#{brick_hash["state"]}"
  params.join("&")
end

def create_brick
  model = Brick.new(brick_hash)
  model.save
  model
end

class BrickControllerTest < GarnetSpec::Controller::Test
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

describe BrickControllerTest do
  subject = BrickControllerTest.new

  it "renders brick index json" do
    Brick.clear
    model = create_brick
    response = subject.get "/bricks"

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "renders brick show json" do
    Brick.clear
    model = create_brick
    location = "/bricks/#{model.id}"

    response = subject.get location

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "creates a brick" do
    Brick.clear
    response = subject.post "/bricks", body: brick_params

    response.status_code.should eq(201)
    response.body.should contain "Fake"
  end

  it "updates a brick" do
    Brick.clear
    model = create_brick
    response = subject.patch "/bricks/#{model.id}", body: brick_params

    response.status_code.should eq(200)
    response.body.should contain "Fake"
  end

  it "deletes a brick" do
    Brick.clear
    model = create_brick
    response = subject.delete "/bricks/#{model.id}"

    response.status_code.should eq(204)
  end
end
