require "./spec_helper"

def volume_hash
  {"name" => "Fake", "state" => "Fake", "type" => "Fake"}
end

def volume_params
  params = [] of String
  params << "name=#{volume_hash["name"]}"
  params << "state=#{volume_hash["state"]}"
  params << "type=#{volume_hash["type"]}"
  params.join("&")
end

def create_volume
  model = Volume.new(volume_hash)
  model.save
  model
end

class VolumeControllerTest < GarnetSpec::Controller::Test
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

describe VolumeControllerTest do
  subject = VolumeControllerTest.new

  it "renders volume index json" do
    Volume.clear
    model = create_volume
    response = subject.get "/volumes"

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "renders volume show json" do
    Volume.clear
    model = create_volume
    location = "/volumes/#{model.id}"

    response = subject.get location

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "creates a volume" do
    Volume.clear
    response = subject.post "/volumes", body: volume_params

    response.status_code.should eq(201)
    response.body.should contain "Fake"
  end

  it "updates a volume" do
    Volume.clear
    model = create_volume
    response = subject.patch "/volumes/#{model.id}", body: volume_params

    response.status_code.should eq(200)
    response.body.should contain "Fake"
  end

  it "deletes a volume" do
    Volume.clear
    model = create_volume
    response = subject.delete "/volumes/#{model.id}"

    response.status_code.should eq(204)
  end
end
