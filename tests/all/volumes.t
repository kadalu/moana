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
  TEST "kadalu node join #{node} http://#{node}:3000 -c mycluster"
  puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/nodes/server1/info"

  USE_NODE node
  puts TEST "cat /var/lib/kadalu/info"
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
TEST "kadalu volume create mycluster/vol1 server1:/exports/vol1/s1 server2:/exports/vol1/s2 server3:/exports/vol1/s3"
puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/volumes/vol1/info"

# Replicate
TEST "kadalu volume create mycluster/vol2 replica server1:/exports/vol2/s1 server2:/exports/vol2/s2 server3:/exports/vol2/s3"
puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/volumes/vol2/info"

# Disperse
TEST "kadalu volume create mycluster/vol3 data server1:/exports/vol3/s1 server2:/exports/vol3/s2 redundancy server3:/exports/vol3/s3"
puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/volumes/vol3/info"

# Distributed Replicate
TEST "kadalu volume create mycluster/vol4 replica server1:/exports/vol4/s1 server2:/exports/vol4/s2 server3:/exports/vol4/s3 replica server1:/exports/vol4/s4 server2:/exports/vol4/s5 server3:/exports/vol4/s6"
puts TEST "cat /var/lib/kadalu/meta/clusters/mycluster/volumes/vol4/info"

nodes.each do |node|
  USE_NODE node

  # TODO: Validate Number of Storage unit or brick processes running
  puts TEST "ps ax | grep storage_unit | grep vol1"
  puts TEST "ps ax | grep storage_unit | grep vol2"
  puts TEST "ps ax | grep storage_unit | grep vol3"
  puts TEST "ps ax | grep storage_unit | grep vol4"
end
