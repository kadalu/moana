require "digest/sha256"

require "kemal"

require "../actions"

post "/_apis/v1/:action" do |env|
  action = env.params.url["action"]
  begin
    req = env.params.json["data"].as(String)
    resp = Action.run(action, req)
    env.response.status_code = 400 if !resp.ok
  rescue ex : Exception
    Log.error &.emit("#{action} Failed", error: "#{ex}")
    env.response.status_code = 500
    resp = NodeResponse.new(false, {"error": "#{action} Failed"}.to_json)
  end

  resp.status_code = env.response.status_code
  resp.to_json
end

def node_action(name, &block : String -> NodeResponse)
  Action.add(name, &block)
end

def dispatch_action(name, cluster_name, nodes, data)
  Action.dispatch(name, cluster_name, nodes, data)
end

def dispatch_action(name, cluster_name, nodes)
  Action.dispatch(name, cluster_name, nodes, "")
end

def metrics_collector(name : String, &block : MgrTypes::Cluster -> Nil)
  MetricsCollector.add(name, &block)
end

def hash_sha256(value : String)
  Digest::SHA256.digest(value).hexstring
end
