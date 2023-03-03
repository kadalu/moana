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
RUN "umount /mnt/vol2"
RUN "rm -rf /mnt/vol2"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add #{node}"
end

nodes.each do |node|
  USE_NODE node
  RUN "rm -rf /exports/*"
  TEST "mkdir -p /exports/vol1"
end

# After nodes are added, try execute commands in other agent nodes
USE_NODE nodes[1]
puts TEST "kadalu user login admin --password=kadalu"

# Distribute
TEST "kadalu pool create vol1 server1:/exports/vol1/s1 server2:/exports/vol1/s2 server3:/exports/vol1/s3"

nodes.each do |node|
  USE_NODE node

  # TODO: Validate Number of Storage unit or brick processes running
  puts TEST "ps ax | grep storage_unit | grep vol1"
end

USE_NODE nodes[1]
TEST "mkdir /mnt/vol1"
TEST "chattr +i /mnt/vol1"
puts TEST "mount -t kadalu http://#{nodes[1]}:3000:vol1 /mnt/vol1"

TEST "echo \"Hello World\" > /mnt/vol1/f1"
# TODO: Validate this value below
content = TEST "cat /mnt/vol1/f1"
EQUAL content.strip, "Hello World", "/mnt/vol1/f1 content is \"Hello World\""

TEST "kadalu pool stop vol1 --mode=script"
TEST "kadalu pool delete vol1 --mode=script"

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove #{node} --mode=script"
end

puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
end
