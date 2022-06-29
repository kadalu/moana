require "./helpers"

ACTION_PING = "ping"

node_action ACTION_PING do |_data, _env|
  NodeResponse.new(true, "")
end

get "/ping" do |_env|
  "{}"
end
