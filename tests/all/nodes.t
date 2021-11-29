# -*- mode: ruby -*-

load "#{File.dirname(__FILE__)}/../reset.t"

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

USE_NODE nodes[0]
TEST "systemctl enable kadalu-mgr"
TEST "systemctl start kadalu-mgr"
puts TEST "kadalu cluster create mycluster"
TEST "cat /var/lib/kadalu/meta/clusters/mycluster/info"

nodes[1 .. -1].each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-agent"
  TEST "systemctl start kadalu-agent"
end

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node join mycluster/#{node}"
  puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/nodes/server1/info"

  USE_NODE node
  puts TEST "cat /var/lib/kadalu/info"
end

USE_NODE nodes[0]
puts TEST "kadalu node list mycluster"
puts TEST "kadalu node list mycluster --status"
