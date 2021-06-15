# -*- mode: ruby -*-
workdir = ENV["WORKDIR"]

nodes = ["server1.p1", "server2.p1", "server3.p1"]
control_nodes = ["moana.p1"]

nodes.each do |node|
  TEST "docker stop #{node}"
  TEST "docker rm #{node}"
end

control_nodes.each do |control_node|
  TEST "docker stop #{control_node}"
  TEST "docker rm #{control_node}"
end

TEST "docker network rm p1"
