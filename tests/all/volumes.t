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
puts TEST "kadalu pool create DEV"
RUN "umount /mnt/vol2"
RUN "rm -rf /mnt/vol2"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add DEV/#{node}"
end

nodes.each do |node|
  USE_NODE node
  RUN "rm -rf /exports/*"
  TEST "mkdir -p /exports/vol1"
  TEST "mkdir -p /exports/vol2"
  TEST "mkdir -p /exports/vol3"
  TEST "mkdir -p /exports/vol4"
  TEST "mkdir -p /exports/vol5"
  TEST "mkdir -p /exports/vol6"
  TEST "mkdir -p /exports/vol7"
  TEST "mkdir -p /exports/vol8"
  TEST "mkdir -p /exports/vol9"
  TEST "mkdir -p /exports/vol10/s1"
  TEST "mkdir -p /exports/vol11"
  TEST "mkdir -p /exports/vol12"
  TEST "mkdir -p /exports/vol14"
  TEST "mkdir -p /exports/vol19"
end

USE_NODE nodes[0]
# Distribute
TEST "kadalu volume create DEV/vol1 server1:/exports/vol1/s1 server2:/exports/vol1/s2 server3:/exports/vol1/s3"

# Replicate
TEST "kadalu volume create DEV/vol2 replica server1:/exports/vol2/s1 server2:/exports/vol2/s2 server3:/exports/vol2/s3"

# Disperse
TEST "kadalu volume create DEV/vol3 data server1:/exports/vol3/s1 server2:/exports/vol3/s2 redundancy server3:/exports/vol3/s3"

# Distributed Replicate
TEST "kadalu volume create DEV/vol4 replica server1:/exports/vol4/s1 server2:/exports/vol4/s2 server3:/exports/vol4/s3 replica server1:/exports/vol4/s4 server2:/exports/vol4/s5 server3:/exports/vol4/s6"

puts TEST "kadalu volume list --json"

nodes.each do |node|
  USE_NODE node

  # TODO: Validate Number of Storage unit or brick processes running
  puts TEST "ps ax | grep storage_unit | grep vol1"
  puts TEST "ps ax | grep storage_unit | grep vol2"
  puts TEST "ps ax | grep storage_unit | grep vol3"
  puts TEST "ps ax | grep storage_unit | grep vol4"
end

USE_NODE nodes[0]
TEST "mkdir /mnt/vol2"
TEST "chattr +i /mnt/vol2"
TEST "mount -t kadalu #{nodes[0]}:DEV/vol2 /mnt/vol2"

TEST "echo \"Hello World\" > /mnt/vol2/f1"
# TODO: Validate this value below
content = TEST "cat /mnt/vol2/f1"
EQUAL content.strip, "Hello World", "/mnt/vol2/f1 content is \"Hello World\""

nodes.each_with_index do |node, idx|
  USE_NODE node

  content = TEST "cat /exports/vol2/s#{idx+1}/f1"
  EQUAL content.strip, "Hello World", "/exports/vol2/s#{idx+1}/f1 content is \"Hello World\""
end

USE_NODE nodes[0]
["vol1", "vol2", "vol3", "vol4"].each do |vol|
  TEST "kadalu volume stop DEV/#{vol} --mode=script"
  TEST "kadalu volume delete DEV/#{vol} --mode=script"
end

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove DEV/#{node} --mode=script"
end

puts TEST "kadalu pool delete DEV --mode=script"

USE_NODE nodes[0]
TEST "kadalu volume create DEV/vol5 server1:/exports/vol5/s1 server2:/exports/vol5/s2 server3:/exports/vol5/s3 --auto-create-pool --auto-add-nodes"
TEST "kadalu volume stop DEV/vol5 --mode=script"
TEST "kadalu volume delete DEV/vol5 --mode=script"

# Tests for volume re-use usecase
def create_volume_and_get_id(cmd)
    out = TEST cmd
    last_line = out.strip.split("\n")[-1]
    vol_id = last_line.nil? ? "" : last_line.split(":")[-1].strip
    vol_id
end

# Can ignore --auto-create-pools & --auto-add-nodes since it already created & not deleted.
# Case 1
# Create vol6 & delete it. Reuse the same path with --volume-id for vol7.
USE_NODE nodes[0]
vol_id = create_volume_and_get_id("kadalu volume create DEV/vol6 server1:/exports/vol6/s1 server2:/exports/vol6/s2 server3:/exports/vol6/s3 --no-start")
TEST "kadalu volume delete DEV/vol6 --mode=script"
new_vol_id = create_volume_and_get_id("kadalu volume create DEV/vol7 server1:/exports/vol6/s1 server2:/exports/vol6/s2 server3:/exports/vol6/s3 --no-start --volume-id=#{vol_id}")
EQUAL vol_id, new_vol_id, "Checking if volume-id are equal after vol6 is reused with --volume-id in vol7"
TEST "kadalu volume delete DEV/vol7 --mode=script"

# Case 2
# Create vol8. Create vol9 with --volume-id of active vol8.
vol_id = create_volume_and_get_id("kadalu volume create DEV/vol8 server1:/exports/vol8/s1 server2:/exports/vol8/s2 server3:/exports/vol8/s3 --no-start")
TEST 1, "kadalu volume create DEV/vol9 server1:/exports/vol9/s1 server2:/exports/vol9/s2 server3:/exports/vol9/s3 --no-start --volume-id=#{vol_id}"
TEST "kadalu volume delete DEV/vol8 --mode=script"

# Case 3
# Create vol10 with full storage-unit directory
TEST "kadalu volume create DEV/vol10 server1:/exports/vol10/s1 --no-start"
TEST "kadalu volume delete DEV/vol10 --mode=script"

# Case 4 [Negation of Case1]
# Create vol11 & delete it. Create vol12 with same path of unactive vol11 without --volume-id.
TEST "kadalu volume create DEV/vol11 server1:/exports/vol11/s1 server2:/exports/vol11/s2 server3:/exports/vol11/s3 --no-start"
TEST "kadalu volume delete DEV/vol11 --mode=script"
TEST 1, "kadalu volume create DEV/vol12 server1:/exports/vol11/s1 server2:/exports/vol11/s2 server3:/exports/vol11/s3 --no-start"

# Case 5
# Create vol13 with fresh path & no xattrs using --volume-id with wrong format. [Check for matching format of vol-id with uuid]
TEST 1, "kadalu volume create DEV/vol13 server1:/exports/vol12/s1 server2:/exports/vol12/s2 server3:/exports/vol12/s3 --no-start --volume-id=123-456-789"


# Tests for restarting of all services on node-reboot
TEST "kadalu volume create DEV/vol14 server1:/exports/vol14/s1 server2:/exports/vol14/s2 server3:/exports/vol14/s3"
nodes.each do |node|
  USE_NODE node
  puts TEST "ps aux | grep 'glusterfsd'"
  EQUAL "1", (TEST "ps aux | grep '[g]lusterfsd'| wc -l").strip, "Check for equal number of services[brick-processes]"
  puts TEST "kill $(pidof 'glusterfsd')"
  TEST "systemctl restart kadalu-mgr"
  puts TEST "ps aux | grep 'glusterfsd'"
  EQUAL "1", (TEST "ps aux | grep '[g]lusterfsd'| wc -l").strip, "Check for equal number of services[brick-processes]"
  puts TEST "cat /var/log/kadalu/storage_units/*;"
end

USE_NODE nodes[0]
TEST "kadalu volume stop DEV/vol14 --mode=script"
TEST "kadalu volume delete DEV/vol14 --mode=script"

# Tests for Backup & Restore
TEST "kadalu volume create DEV/vol19 server1:/exports/vol19/s1 server2:/exports/vol19/s2 server3:/exports/vol19/s3"
USE_NODE nodes[0]
TEST "kadalu config-snapshot create snap1"
puts TEST "kadalu config-snapshot list"

TEST "systemctl stop kadalu-mgr"
TEST "rm -rf /var/lib/kadalu/meta /var/lib/kadalu/info"

TEST "kadalu config-snapshot restore snap1 --mode=script"

TEST "systemctl start kadalu-mgr"

TEST "kadalu volume stop DEV/vol19 --mode=script"
TEST "kadalu volume delete DEV/vol19 --mode=script"

puts TEST "kadalu volume list --json"

TEST "kadalu config-snapshot create snap2"
puts TEST "kadalu config-snapshot list"
TEST "kadalu config-snapshot delete snap2 --mode=script"
puts TEST "kadalu config-snapshot list"

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove DEV/#{node} --mode=script"
end

puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
end
