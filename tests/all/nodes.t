# -*- mode: ruby -*-

load "#{File.dirname(__FILE__)}/../reset.t"

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end

USE_NODE nodes[0]
puts TEST "kadalu pool create DEV"
TEST "cat /var/lib/kadalu/meta/pools/DEV/info"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add DEV/#{node}"
  puts TEST "cat /var/lib/kadalu/meta/pools/DEV/nodes/server1/info"

  USE_NODE node
  puts TEST "cat /var/lib/kadalu/info"
  puts TEST "ls /var/lib/kadalu/meta"
end

USE_NODE nodes[0]
puts TEST "kadalu node list DEV"
puts TEST "kadalu node list DEV --status"
