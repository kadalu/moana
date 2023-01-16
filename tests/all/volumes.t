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
  TEST "mkdir -p /exports/vol15"
  TEST "mkdir -p /exports/vol16"
  TEST "mkdir -p /exports/vol17"
  TEST "mkdir -p /exports/vol18"
  TEST "mkdir -p /exports/vol19"
  TEST "mkdir -p /exports/vol20a"
  TEST "mkdir -p /exports/vol20b"
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
puts TEST "mount -t kadalu http://#{nodes[0]}:3000:DEV/vol2 /mnt/vol2"

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
end

USE_NODE nodes[0]
TEST "kadalu volume stop DEV/vol14 --mode=script"
TEST "kadalu volume delete DEV/vol14 --mode=script"

# Volfile Server tests
# Volume create with known Storage unit port
TEST "mkdir -p /exports/vol_volfile/s1"
TEST "kadalu volume create DEV/vol_volfile server1:5007:/exports/vol_volfile/s1"
puts TEST "ls /var/lib/kadalu/volfiles"

# Mount the Volume
TEST "mkdir -p /mnt/vol_volfile"
TEST "glusterfs -s server1:5007 --volfile-id vol_volfile -l/tmp/volspec.log /mnt/vol_volfile"
puts TEST "df /mnt/vol_volfile"

# Use mount command (Different options)
# Using Mgr URL
TEST "mkdir -p /mnt/vol_volfile_1"
puts TEST "mount -t kadalu http://server1:3000:/DEV/vol_volfile /mnt/vol_volfile_1"
puts TEST "df /mnt/vol_volfile_1"

# TODO: Mgr URL from ENV
TEST "mkdir -p /mnt/vol_volfile_2"
puts TEST "mount -t kadalu /DEV/vol_volfile /mnt/vol_volfile_2"
puts TEST "df /mnt/vol_volfile_2"

# Using Storage Unit URL directly
TEST "mkdir -p /mnt/vol_volfile_3"
puts TEST "mount -t kadalu server1:5007:/DEV/vol_volfile /mnt/vol_volfile_3"
puts TEST "df /mnt/vol_volfile_3"

# Using Volfile Server option
TEST "mkdir -p /mnt/vol_volfile_4"
puts TEST "mount -t kadalu -o \"volfile-server=server1:5007\" /DEV/vol_volfile /mnt/vol_volfile_4"
puts TEST "df /mnt/vol_volfile_4"

# Using Volfile Servers option
TEST "mkdir -p /mnt/vol_volfile_5"
puts TEST "mount -t kadalu -o \"volfile-servers=server1:5007 server1:5007\" /DEV/vol_volfile /mnt/vol_volfile_5"
puts TEST "df /mnt/vol_volfile_5"

# Using Volfile Path option
TEST "mkdir -p /mnt/vol_volfile_6"
puts TEST "mount -t kadalu /var/lib/kadalu/volfiles/vol_volfile.vol /mnt/vol_volfile_6"
puts TEST "df /mnt/vol_volfile_6"

TEST "umount /mnt/vol_volfile_*"

# Change option using Volume set
TEST "kadalu volume set DEV/vol_volfile debug/io-stats.log-level DEBUG"
TEST "sleep 5"

# Print the mount log to see if the option changed is reflected
puts TEST "cat /tmp/volspec.log"
TEST "grep -q \"Volume file changed\" /tmp/volspec.log"

TEST "umount /mnt/vol_volfile"

TEST "kadalu volume stop DEV/vol_volfile --mode=script"
TEST "kadalu volume delete DEV/vol_volfile --mode=script"

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

# Tests for volume expansion
# Distribute
TEST "kadalu volume create DEV/vol15 server1:/exports/vol15/s1 server2:/exports/vol15/s2 server3:/exports/vol15/s3"
TEST "mkdir -p /mnt/vol15"
puts TEST "kadalu mount DEV/vol15 /mnt/vol15"
puts TEST "df /mnt/vol15"
TEST "mkdir /mnt/vol15/d1 /mnt/vol15/d2 /mnt/vol15/d3"
TEST "touch /mnt/vol15/d1/f{1..9}"
TEST "touch /mnt/vol15/d2/f{1..9}"
TEST "touch /mnt/vol15/d3/f{1..9}"
TEST "kadalu volume expand DEV/vol15 server1:/exports/vol15/s1_e server2:/exports/vol15/s2_e server3:/exports/vol15/s3_e"

EQUAL "3", (TEST "ls /exports/vol15/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/vol15/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/vol15/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit"

USE_NODE nodes[0]
TEST "kadalu volume rebalance-start DEV/vol15"
TEST "sleep 3"

EQUAL "3", (TEST "ls /exports/vol15/s1/d1/f3 /exports/vol15/s1/d2/f3 /exports/vol15/s1/d3/f3 | wc -l").strip, "Check for migrate-data in server1 s1 unit vol15"
EQUAL "5", (TEST "ls /exports/vol15/s1_e/d1/f4 /exports/vol15/s1_e/d2/f1 /exports/vol15/s1_e/d2/f5 /exports/vol15/s1_e/d3/f1 /exports/vol15/s1_e/d3/f5 | wc -l").strip, "Check for migrate-data in server1 s1_e unit"

USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/vol15/s2/d1/f2 /exports/vol15/s2/d2/f2 /exports/vol15/s2/d3/f2 | wc -l").strip, "Check for migrate-data in server2 s2 unit vol15"
EQUAL "9", (TEST "ls /exports/vol15/s2_e/d1/f6 /exports/vol15/s2_e/d1/f7 /exports/vol15/s2_e/d1/f9 /exports/vol15/s2_e/d2/f6 /exports/vol15/s2_e/d2/f7 /exports/vol15/s2_e/d2/f9 /exports/vol15/s2_e/d3/f6 /exports/vol15/s2_e/d3/f7 /exports/vol15/s2_e/d3/f9 | wc -l
").strip, "Check for migrate-data in server2 s2_e unit"

USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/vol15/s3/d1/f8 /exports/vol15/s3/d2/f4 /exports/vol15/s3/d3/f4 | wc -l ").strip, "Check for migrate-data in server3 s3 unit vol15"
EQUAL "4", (TEST "ls /exports/vol15/s3_e/d1/f1 /exports/vol15/s3_e/d1/f5 /exports/vol15/s3_e/d2/f8 /exports/vol15/s3_e/d3/f8 | wc -l").strip, "Check for migrate-data in server3 s3_e unit"

USE_NODE nodes[0]
TEST "umount /mnt/vol15"
TEST "rmdir /mnt/vol15"
TEST "kadalu volume stop DEV/vol15 --mode=script"
TEST "kadalu volume delete DEV/vol15 --mode=script"

# Replicate
TEST "kadalu volume create DEV/vol16 replica server1:/exports/vol16/s1 server2:/exports/vol16/s2 server3:/exports/vol16/s3"
TEST "mkdir -p /mnt/vol16"
puts TEST "kadalu mount DEV/vol16 /mnt/vol16"
puts TEST "df /mnt/vol16"
TEST "mkdir /mnt/vol16/d1 /mnt/vol16/d2 /mnt/vol16/d3"
TEST "touch /mnt/vol16/d1/f{1..9}"
TEST "touch /mnt/vol16/d2/f{1..9}"
TEST "touch /mnt/vol16/d3/f{1..9}"

TEST "kadalu volume expand DEV/vol16 replica server1:/exports/vol16/s1_e server2:/exports/vol16/s2_e server3:/exports/vol16/s3_e"

EQUAL "3", (TEST "ls /exports/vol16/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit vol16"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/vol16/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit vol16"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/vol16/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit vol16"

USE_NODE nodes[0]
TEST "kadalu volume rebalance-start DEV/vol16"
TEST "sleep 3"

EQUAL "5", (TEST "ls /exports/vol16/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit vol16"

EQUAL "4", (TEST "ls /exports/vol16/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit vol16"

USE_NODE nodes[1]
EQUAL "5", (TEST "ls /exports/vol16/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit vol16"

EQUAL "4", (TEST "ls /exports/vol16/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit vol16"

USE_NODE nodes[2]
EQUAL "5", (TEST "ls /exports/vol16/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit vol16"
EQUAL "4", (TEST "ls /exports/vol16/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit vol16"

EQUAL "4", (TEST "ls /exports/vol16/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit vol16"
EQUAL "5", (TEST "ls /exports/vol16/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit vol16"

USE_NODE nodes[0]
TEST "umount /mnt/vol16"
TEST "rmdir /mnt/vol16"

TEST "kadalu volume stop DEV/vol16 --mode=script"
TEST "kadalu volume delete DEV/vol16 --mode=script"

# Distributed Replicate
TEST "kadalu volume create DEV/vol17 replica server1:/exports/vol17/s1 server2:/exports/vol17/s2 server3:/exports/vol17/s3 replica server1:/exports/vol17/s4 server2:/exports/vol17/s5 server3:/exports/vol17/s6"
TEST "mkdir -p /mnt/vol17"
puts TEST "kadalu mount DEV/vol17 /mnt/vol17"
puts TEST "df /mnt/vol17"
TEST "mkdir /mnt/vol17/d1 /mnt/vol17/d2 /mnt/vol17/d3"
TEST "touch /mnt/vol17/d1/f{1..9}"
TEST "touch /mnt/vol17/d2/f{1..9}"
TEST "touch /mnt/vol17/d3/f{1..9}"

TEST "kadalu volume expand DEV/vol17 replica server1:/exports/vol17/s1_e server2:/exports/vol17/s2_e server3:/exports/vol17/s3_e replica server1:/exports/vol17/s4_e server2:/exports/vol17/s5_e server3:/exports/vol17/s6_e"

EQUAL "3", (TEST "ls /exports/vol17/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s4_e/* -d | wc -l").strip, "Check for fix-layout in server1 s4 unit vol17"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/vol17/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s5_e/* -d | wc -l").strip, "Check for fix-layout in server2 s5 unit vol17"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/vol17/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s6_e/* -d | wc -l").strip, "Check for fix-layout in server3 s6 unit vol17"

USE_NODE nodes[0]
TEST "kadalu volume rebalance-start DEV/vol17"
TEST "sleep 3"

EQUAL "2", (TEST "ls /exports/vol17/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s4/d1/ | wc -l").strip, "Check for migrate-data in server1 s4/d1 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s4/d2/ | wc -l").strip, "Check for migrate-data in server1 s4/d2 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s4/d3/ | wc -l").strip, "Check for migrate-data in server1 s4/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit vol17"

EQUAL "3", (TEST "ls /exports/vol17/s4_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s4_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s4_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d3 unit vol17"

USE_NODE nodes[1]
EQUAL "2", (TEST "ls /exports/vol17/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s5/d1/ | wc -l").strip, "Check for migrate-data in server2 s5/d1 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s5/d2/ | wc -l").strip, "Check for migrate-data in server2 s5/d2 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s5/d3/ | wc -l").strip, "Check for migrate-data in server2 s5/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit vol17"

EQUAL "3", (TEST "ls /exports/vol17/s5_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s5_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s5_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d3 unit vol17"

USE_NODE nodes[2]
EQUAL "2", (TEST "ls /exports/vol17/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s6/d1/ | wc -l").strip, "Check for migrate-data in server3 s6/d1 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s6/d2/ | wc -l").strip, "Check for migrate-data in server3 s6/d2 unit vol17"
EQUAL "3", (TEST "ls /exports/vol17/s6/d3/ | wc -l").strip, "Check for migrate-data in server3 s6/d3 unit vol17"

EQUAL "2", (TEST "ls /exports/vol17/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit vol17"

EQUAL "3", (TEST "ls /exports/vol17/s6_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d1 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s6_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d2 unit vol17"
EQUAL "2", (TEST "ls /exports/vol17/s6_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d3 unit vol17"

USE_NODE nodes[0]
TEST "umount /mnt/vol17"
TEST "rmdir /mnt/vol17"

TEST "kadalu volume stop DEV/vol17 --mode=script"
TEST "kadalu volume delete DEV/vol17 --mode=script"

# Disperse
TEST "kadalu volume create DEV/vol18 data server1:/exports/vol18/s1 server2:/exports/vol18/s2 redundancy server3:/exports/vol18/s3"
TEST "mkdir -p /mnt/vol18"
puts TEST "kadalu mount DEV/vol18 /mnt/vol18"
puts TEST "df /mnt/vol18"
TEST "mkdir /mnt/vol18/d1 /mnt/vol18/d2 /mnt/vol18/d3"
TEST "touch /mnt/vol18/d1/f{1..9}"
TEST "touch /mnt/vol18/d2/f{1..9}"
TEST "touch /mnt/vol18/d3/f{1..9}"

TEST "kadalu volume expand DEV/vol18 data server1:/exports/vol18/s1_e server2:/exports/vol18/s2_e redundancy server3:/exports/vol18/s3_e"

EQUAL "3", (TEST "ls /exports/vol18/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit vol18"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/vol18/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit vol18"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/vol18/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit vol18"

USE_NODE nodes[0]
TEST "kadalu volume rebalance-start DEV/vol18"
TEST "sleep 3"

EQUAL "5", (TEST "ls /exports/vol18/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit vol18"

EQUAL "4", (TEST "ls /exports/vol18/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit vol18"

USE_NODE nodes[1]
EQUAL "5", (TEST "ls /exports/vol18/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit vol18"

EQUAL "4", (TEST "ls /exports/vol18/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit vol18"

USE_NODE nodes[2]
EQUAL "5", (TEST "ls /exports/vol18/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit vol18"
EQUAL "4", (TEST "ls /exports/vol18/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit vol18"

EQUAL "4", (TEST "ls /exports/vol18/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit vol18"
EQUAL "5", (TEST "ls /exports/vol18/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit vol18"

USE_NODE nodes[0]
TEST "umount /mnt/vol18"
TEST "rmdir /mnt/vol18"

TEST "kadalu volume stop DEV/vol18 --mode=script"
TEST "kadalu volume delete DEV/vol18 --mode=script"

puts TEST "kadalu volume list --json"

TEST "kadalu config-snapshot create snap2"
puts TEST "kadalu config-snapshot list"
TEST "kadalu config-snapshot delete snap2 --mode=script"
puts TEST "kadalu config-snapshot list"

# Tests for renaming of volume
USE_NODE nodes[0]
TEST "kadalu volume create DEV/vol20a server1:/exports/vol20a/s1 --no-start"
TEST "kadalu volume create DEV/vol20b server1:/exports/vol20b/s1 server2:/exports/vol20b/s2 server3:/exports/vol20b/s3 --no-start"
puts TEST "kadalu pool create DEV2"
TEST 1, "kadalu volume rename DEV/vol20b DEV2/vol20b"

TEST "kadalu volume delete DEV/vol20a --mode=script"
TEST 0, "kadalu volume rename DEV/vol20b DEV2/vol20b"

puts TEST "kadalu node list"

TEST "kadalu volume delete DEV2/vol20b --mode=script"

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove DEV2/#{node} --mode=script"
end

puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
  puts TEST "cat /var/log/kadalu/storage_units/*;"
end
