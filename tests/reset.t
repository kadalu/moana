# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

USE_NODE nodes[0]
RUN "systemctl stop kadalu-mgr"
RUN "systemctl disable kadalu-mgr"
RUN "rm -rf /var/lib/kadalu"

nodes[1 .. -1].each do |node|
  USE_NODE node
  RUN "systemctl stop kadalu-agent"
  RUN "systemctl disable kadalu-agent"
  RUN "rm -rf /var/lib/kadalu"
end
