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
puts TEST "kadalu user password --current-password=kadalu --new-password=uladak"
puts TEST "kadalu user login admin --password=uladak"
puts TEST "kadalu api-key list"
puts TEST "kadalu api-key list --json"
puts TEST "kadalu api-key create Dev"
api_key = TEST "kadalu api-key list | grep Dev | awk '{print $1}'"
puts TEST "kadalu api-key delete #{api_key}"
puts TEST "kadalu user logout"
puts TEST "kadalu user login admin --password=uladak"
puts TEST "kadalu user delete admin --mode=script"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
end

