require "./spec_helper"

def task_hash
  {"data" => "Fake", "state" => "Fake", "type" => "Fake", "response" => "Fake"}
end

def task_params
  params = [] of String
  params << "data=#{task_hash["data"]}"
  params << "state=#{task_hash["state"]}"
  params << "type=#{task_hash["type"]}"
  params << "response=#{task_hash["response"]}"
  params.join("&")
end

def create_task
  model = Task.new(task_hash)
  model.save
  model
end

class TaskControllerTest < GarnetSpec::Controller::Test
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

describe TaskControllerTest do
  subject = TaskControllerTest.new

  it "renders task index json" do
    Task.clear
    model = create_task
    response = subject.get "/tasks"

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "renders task show json" do
    Task.clear
    model = create_task
    location = "/tasks/#{model.id}"

    response = subject.get location

    response.status_code.should eq(200)
    response.body.should contain("Fake")
  end

  it "creates a task" do
    Task.clear
    response = subject.post "/tasks", body: task_params

    response.status_code.should eq(201)
    response.body.should contain "Fake"
  end

  it "updates a task" do
    Task.clear
    model = create_task
    response = subject.patch "/tasks/#{model.id}", body: task_params

    response.status_code.should eq(200)
    response.body.should contain "Fake"
  end

  it "deletes a task" do
    Task.clear
    model = create_task
    response = subject.delete "/tasks/#{model.id}"

    response.status_code.should eq(204)
  end
end
