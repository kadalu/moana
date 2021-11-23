require "kemal"

require "./watcher"
require "./routes"
require "./node_conf"

VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

# Initialize the node configuration
node_conf = NodeConf.new

# Run in periodic interval to get latest tasks from
# Moana Server and handle each task
watcher = Watcher.new(node_conf)
spawn do
  watcher.start
end

# Run the Web service to receive Tasks from different nodes.
# Moana server will not contact the node agent directly. Instead,
# each node agent pulls the list of tasks assigned to respective
# node and then broadcast to all Participating nodes within the
# Cluster and updates the response back to Moana Server.
Kemal.config.port = node_conf.port

# Application name
Kemal.config.app_name = "kadalu-node"

Kemal.run
