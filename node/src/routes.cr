require "kemal"

require "./task/*"

require "./node_conf"

post "/api/v1/join" do |env|
  req = MoanaTypes::NodeJoinRequest.from_json(env.request.body.not_nil!)

  # Node Join request as a Task
  task = Task.from_json(
    {
      type: "node_join",
      data: req.to_json,
    }.to_json
  )

  begin
    task.run(NodeConf.from_conf)
    env.response.status_code = 201

    # Load node configuration again
    conf = NodeConf.from_conf

    # Export the Node JSON
    node = MoanaTypes::Node.new
    node.id = conf.node_id
    node.hostname = conf.hostname
    node.endpoint = conf.endpoint
    node.to_json
  rescue ex : Exception
    env.response.status_code = 500
    {"error": ex.message}.to_json
  end
end
