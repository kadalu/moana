require "kemal"

require "./routes"
require "./node_conf"

# Initialize the node configuration
node_conf = NodeConf.new

# Run the Web service to receive Tasks from different nodes.
# Moana server will not contact the node agent directly. Instead,
# each node agent pulls the list of tasks assigned to respective
# node and then broadcast to all Participating nodes within the
# Cluster and updates the response back to Moana Server.
Kemal.config.port = node_conf.port
Kemal.run
