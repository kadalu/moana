# -*- mode: ruby -*-

USE_REMOTE_PLUGIN "docker"
nodes = ["server1", "server2", "server3"]

# Static build Kadalu Storage Manager
TEST "docker run --rm -i -v $PWD:/workspace -w /workspace crystallang/crystal:1.2.0-alpine /bin/sh -c \"cd mgr && shards install && shards build --static\""

# Install the Static binary to all containers/nodes
# and copy the service files
nodes.each do |node|
  USE_NODE node do
    RUN "rm -rf /usr/lib/python3/dist-packages/kadalu"
    RUN "rm -rf /moana_python_sdk_test_scripts/"
  end

  TEST "docker cp ./mgr/bin/kadalu #{node}:/usr/sbin/kadalu"
  TEST "docker cp ./clients/python/kadalu #{node}:/usr/lib/python3/dist-packages/kadalu"
  TEST "docker cp ./clients/python/test_scripts #{node}:/moana_python_sdk_test_scripts"
  TEST "docker cp extra/kadalu-mgr.service #{node}:/lib/systemd/system/"
  TEST "docker cp extra/mount.kadalu #{node}:/sbin/mount.kadalu"
end

# Sanity test
USE_NODE nodes[0]
puts TEST "kadalu version"
