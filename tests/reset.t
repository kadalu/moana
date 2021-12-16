# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

nodes.each do |node|
  USE_NODE node
  RUN "systemctl stop kadalu-mgr"
  RUN "systemctl disable kadalu-mgr"
  RUN "rm -rf /var/lib/kadalu"
end
