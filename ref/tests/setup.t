# -*- mode: ruby -*-
workdir = ENV["WORKDIR"]
nodes = ["server1.p1", "server2.p1", "server3.p1"]
control_nodes = ["control.p1"]

TEST "docker network create p1"
TEST "docker build . --tag docker.io/kadalu-server-dev -f tests/Dockerfile"

nodes.each do |node|
  TEST "docker run -d \
    -v /sys/fs/cgroup/:/sys/fs/cgroup:ro \
    -v #{workdir}/.kadalu/data-#{node}:/var/lib/kadalu \
    -v #{Dir.pwd}:/moana \
    --cap-add SYS_ADMIN \
    --name #{node} \
    --network p1 \
    --hostname #{node} \
    kadalu-server-dev"
end

control_nodes.each do |control_node|
  TEST "docker run -d \
    -v /sys/fs/cgroup/:/sys/fs/cgroup:ro \
    -v #{Dir.pwd}:/moana \
    --cap-add SYS_ADMIN \
    --name #{control_node} \
    -v #{workdir}/.kadalu/data-#{control_node}:/var/lib/kadalu \
    -v #{workdir}/.kadalu/data-#{control_node}-config:/root/.kadalu \
    --network p1 \
    --hostname #{control_node} \
    kadalu-server-dev"
end
