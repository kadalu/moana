# -*- mode: ruby -*-

nodes = ["server1.p1", "server2.p1", "server3.p1"]
control_node = "control.p1"

kadalu = "KADALU_MGMT_SERVER=http://#{control_node}:3000 kadalu"

USE_REMOTE_PLUGIN "docker"

USE_NODE control_node

TEST "#{kadalu} cluster list"
TEST "#{kadalu} cluster create mycluster"
