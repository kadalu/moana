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
puts TEST "kadalu user create admin --password=kadalu"
puts TEST "kadalu user login admin --password=kadalu"
puts TEST "kadalu pool create DEV"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add DEV/#{node}"
end

USE_NODE nodes[0]
puts TEST "kadalu node list DEV"
puts TEST "kadalu node list DEV --status"
puts TEST "kadalu node list DEV --status --json"
nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove DEV/#{node} --mode=script"
end

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/lib/kadalu/info"
end

# Add and remove again to see node cleanup happens after remove
nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add DEV/#{node}"
  TEST "kadalu node remove DEV/#{node} --mode=script"
end

puts TEST "kadalu pool delete DEV --mode=script"
puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
end
