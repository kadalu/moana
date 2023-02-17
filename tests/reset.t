# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

nodes.each do |node|
  USE_NODE node
  RUN "systemctl stop kadalu-mgr"
  RUN "systemctl disable kadalu-mgr"
  RUN "mv /var/lib/kadalu/templates /tmp/"
  RUN "rm -rf /var/lib/kadalu"
  RUN "mkdir -p /var/lib/kadalu"
  RUN "mv /tmp/templates /var/lib/kadalu/"
end
