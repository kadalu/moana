# -*- mode: ruby -*-

load "#{File.dirname(__FILE__)}/../reset.t"

TEST_SCRIPTS = "python3 /moana_python_sdk_test_scripts"

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

USE_NODE nodes[0]
URL = "http://#{nodes[0]}:3000"

TEST "systemctl enable kadalu-mgr"
TEST "systemctl start kadalu-mgr"
puts TEST "#{TEST_SCRIPTS}/pools.py #{URL} create DEV"
TEST "cat /var/lib/kadalu/meta/pools/DEV/info"

nodes[1 .. -1].each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-agent"
  TEST "systemctl start kadalu-agent"
end

USE_NODE nodes[0]
puts TEST "#{TEST_SCRIPTS}/pools.py #{URL} list"
