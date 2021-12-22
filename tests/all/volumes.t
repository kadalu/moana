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
RUN "umount /mnt/vol2"
RUN "rm -rf /mnt/vol2"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add DEV/#{node}"
end

nodes.each do |node|
  USE_NODE node
  RUN "rm -rf /exports/*"
  TEST "mkdir -p /exports/vol1"
  TEST "mkdir -p /exports/vol2"
  TEST "mkdir -p /exports/vol3"
  TEST "mkdir -p /exports/vol4"
end

USE_NODE nodes[0]
# Distribute
TEST "kadalu volume create DEV/vol1 server1:/exports/vol1/s1 server2:/exports/vol1/s2 server3:/exports/vol1/s3"

# Replicate
TEST "kadalu volume create DEV/vol2 replica server1:/exports/vol2/s1 server2:/exports/vol2/s2 server3:/exports/vol2/s3"

# Disperse
TEST "kadalu volume create DEV/vol3 data server1:/exports/vol3/s1 server2:/exports/vol3/s2 redundancy server3:/exports/vol3/s3"

# Distributed Replicate
TEST "kadalu volume create DEV/vol4 replica server1:/exports/vol4/s1 server2:/exports/vol4/s2 server3:/exports/vol4/s3 replica server1:/exports/vol4/s4 server2:/exports/vol4/s5 server3:/exports/vol4/s6"

nodes.each do |node|
  USE_NODE node

  # TODO: Validate Number of Storage unit or brick processes running
  puts TEST "ps ax | grep storage_unit | grep vol1"
  puts TEST "ps ax | grep storage_unit | grep vol2"
  puts TEST "ps ax | grep storage_unit | grep vol3"
  puts TEST "ps ax | grep storage_unit | grep vol4"
end

USE_NODE nodes[0]
TEST "mkdir /mnt/vol2"
TEST "chattr +i /mnt/vol2"
TEST "mount -t kadalu #{nodes[0]}:DEV/vol2 /mnt/vol2"

TEST "echo \"Hello World\" > /mnt/vol2/f1"
# TODO: Validate this value below
content = TEST "cat /mnt/vol2/f1"
EQUAL content.strip, "Hello World", "/mnt/vol2/f1 content is \"Hello World\""

nodes.each_with_index do |node, idx|
  USE_NODE node

  content = TEST "cat /exports/vol2/s#{idx+1}/f1"
  EQUAL content.strip, "Hello World", "/exports/vol2/s#{idx+1}/f1 content is \"Hello World\""
end
