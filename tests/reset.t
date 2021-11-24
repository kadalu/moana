# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

USE_NODE nodes[0]
TEST "systemctl stop kadalu-mgr"
TEST "systemctl disable kadalu-mgr"
TEST "rm -rf /var/lib/kadalu"

nodes[1 .. -1].each do |node|
  USE_NODE node
  TEST "systemctl stop kadalu-agent"
  TEST "systemctl disable kadalu-agent"
  TEST "rm -rf /var/lib/kadalu"
end
