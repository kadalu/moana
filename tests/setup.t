# -*- mode: ruby -*-
USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

# Start three or N storage nodes(Containers)
USE_NODE "local"
nodes.each do |node|
  USE_NODE "local"
  RUN "docker stop #{node}"
  RUN "docker rm #{node}"
end

RUN "docker network rm k1"
TEST "docker network create k1"

nodes.each do |node|
  USE_NODE "local"
  TEST "docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged --name #{node} --hostname #{node} --network k1 kadalu/storage-node-testing"
end
