# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

USE_NODE "server1"
TEST "sudo -H pip install pytest"

USE_NODE "local"
TEST "docker cp sdk/python server1:/root/"

USE_NODE "server1"
TEST "cd /root/python && python3 setup.py install"

load "#{File.dirname(__FILE__)}/../reset.t"
nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end
USE_NODE "server1"

load "#{File.dirname(__FILE__)}/../reset.t"
nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end
USE_NODE "server1"
puts TEST "/usr/local/bin/pytest /root/python/tests/users.py"

load "#{File.dirname(__FILE__)}/../reset.t"
nodes.each do |node|
  USE_NODE node
  TEST "systemctl enable kadalu-mgr"
  TEST "systemctl start kadalu-mgr"
end
USE_NODE "server1"
puts TEST "/usr/local/bin/pytest /root/python/tests/nodes.py"
