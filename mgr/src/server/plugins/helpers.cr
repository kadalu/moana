require "kemal"

require "../actions"

post "/_apis/v1/:action" do |env|
  begin
    resp = Action.run(env.params.url["action"], "")
    env.response.status_code = 400 if !resp.ok
  rescue Exception
    env.response.status_code = 500
    resp = NodeResponse.new(false, "")
  end

  resp.status_code = env.response.status_code
  resp.to_json
end

before_all do |env|
  env.response.content_type = "application/json"
end

def node_action(name, &block : String -> NodeResponse)
  Action.add(name, &block)
end

def dispatch_action(name, nodes, data)
  Action.dispatch(name, nodes, data)
end

def metrics_collector(name : String, &block : MgrTypes::Cluster -> Nil)
  MetricsCollector.add(name, &block)
end
