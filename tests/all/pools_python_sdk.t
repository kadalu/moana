# -*- mode: ruby -*-

load "#{File.dirname(__FILE__)}/../reset.t"

TEST_SCRIPTS = "python3 /moana_python_sdk_test_scripts"

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end

USE_NODE nodes[0]
URL = "http://#{nodes[0]}:3000"
# TODO: Handle User Auth
#puts TEST "#{TEST_SCRIPTS}/pools.py #{URL} create DEV"
#puts TEST "#{TEST_SCRIPTS}/pools.py #{URL} list"
