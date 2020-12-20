require "kemal"

require "./watcher"
require "./routes"

# Run in periodic interval to get latest tasks from
# Moana Server and handle each task
spawn do
  watcher
end

# Run the Web service to receive Tasks from different nodes.
# Moana server will not contact the node agent directly. Instead,
# each node agent pulls the list of tasks assigned to respective
# node and then broadcast to all Participating nodes within the
# Cluster and updates the response back to Moana Server.
Kemal.run
