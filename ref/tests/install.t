# -*- mode: ruby -*-

nodes = ["server1.p1", "server2.p1", "server3.p1"]
control_nodes = ["control.p1"]

USE_REMOTE_PLUGIN "docker"

nodes.each do |node|
  USE_NODE node
  TEST "cp /moana/extra/kadalu-node.service /lib/systemd/system/"
  TEST "systemctl stop kadalu-node"
  TEST "cd /moana/node && shards build --ignore-crystal-version"
  TEST "cp /moana/node/bin/kadalu-node /usr/sbin/kadalu-node"
  TEST "cp /moana/extra/kadalu-brick@.service /lib/systemd/system/"
  TEST "cp /moana/extra/kadalu-brick /usr/sbin/"
  TEST "chmod +x /usr/sbin/kadalu-brick"
  TEST "mkdir -p /var/run/kadalu /var/lib/kadalu/volfiles /var/log/kadalu"
  TEST "systemctl start kadalu-node"
end

control_nodes.each do |control_node|
  USE_NODE control_node
  TEST "cp /moana/extra/kadalu-server.service /lib/systemd/system/"
  TEST "systemctl stop kadalu-server"
  TEST "cd /moana/server && shards build --ignore-crystal-version"
  TEST "cd /moana/cli && shards build --ignore-crystal-version"
  TEST "cp /moana/server/bin/kadalu-server /usr/sbin/kadalu-server"
  TEST "cp /moana/cli/bin/kadalu /usr/sbin/kadalu"
  TEST "mkdir -p /var/run/kadalu /var/lib/kadalu/volfiles /var/log/kadalu"
  TEST "systemctl start kadalu-server"
end
