require "./helpers"

ACTION_PING = "ping"

node_action ACTION_PING do |_|
  NodeResponse.new(true, "")
end
