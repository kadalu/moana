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
RUN "umount /mnt/pool2"
RUN "rm -rf /mnt/pool2"

nodes.each do |node|
  USE_NODE nodes[0]
  TEST "kadalu node add #{node}"
end

nodes.each do |node|
  USE_NODE node
  RUN "rm -rf /exports/*"
  TEST "mkdir -p /exports/pool1"
  TEST "mkdir -p /exports/pool2"
  TEST "mkdir -p /exports/pool3"
  TEST "mkdir -p /exports/pool4"
  TEST "mkdir -p /exports/pool5"
  TEST "mkdir -p /exports/pool6"
  TEST "mkdir -p /exports/pool7"
  TEST "mkdir -p /exports/pool8"
  TEST "mkdir -p /exports/pool9"
  TEST "mkdir -p /exports/pool10/s1"
  TEST "mkdir -p /exports/pool11"
  TEST "mkdir -p /exports/pool12"
  TEST "mkdir -p /exports/pool14"
  TEST "mkdir -p /exports/pool15"
  TEST "mkdir -p /exports/pool16"
  TEST "mkdir -p /exports/pool17"
  TEST "mkdir -p /exports/pool18"
  TEST "mkdir -p /exports/pool19"
  TEST "mkdir -p /exports/pool20a"
  TEST "mkdir -p /exports/pool20b"
end

USE_NODE nodes[0]
# Distribute
TEST "kadalu pool create pool1 --distribute server1:/exports/pool1/s1 server2:/exports/pool1/s2 server3:/exports/pool1/s3"

# Replicate
TEST "kadalu pool create pool2 replica server1:/exports/pool2/s1 server2:/exports/pool2/s2 server3:/exports/pool2/s3"

# Disperse
TEST "kadalu pool create pool3 data server1:/exports/pool3/s1 server2:/exports/pool3/s2 redundancy server3:/exports/pool3/s3"

# Distributed Replicate
TEST "kadalu pool create pool4 --distribute replica server1:/exports/pool4/s1 server2:/exports/pool4/s2 server3:/exports/pool4/s3 replica server1:/exports/pool4/s4 server2:/exports/pool4/s5 server3:/exports/pool4/s6"

puts TEST "kadalu pool list --json"

nodes.each do |node|
  USE_NODE node

  # TODO: Validate Number of Storage unit or brick processes running
  puts TEST "ps ax | grep storage_unit | grep pool1"
  puts TEST "ps ax | grep storage_unit | grep pool2"
  puts TEST "ps ax | grep storage_unit | grep pool3"
  puts TEST "ps ax | grep storage_unit | grep pool4"
end

USE_NODE nodes[0]
TEST "mkdir /mnt/pool2"
TEST "chattr +i /mnt/pool2"
puts TEST "mount -t kadalu http://#{nodes[0]}:3000:pool2 /mnt/pool2"

TEST "echo \"Hello World\" > /mnt/pool2/f1"
# TODO: Validate this value below
content = TEST "cat /mnt/pool2/f1"
EQUAL content.strip, "Hello World", "/mnt/pool2/f1 content is \"Hello World\""

nodes.each_with_index do |node, idx|
  USE_NODE node

  content = TEST "cat /exports/pool2/s#{idx+1}/f1"
  EQUAL content.strip, "Hello World", "/exports/pool2/s#{idx+1}/f1 content is \"Hello World\""
end

USE_NODE nodes[0]
["pool1", "pool2", "pool3", "pool4"].each do |pool|
  TEST "kadalu pool stop #{pool} --mode=script"
  TEST "kadalu pool delete #{pool} --mode=script"
end

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove #{node} --mode=script"
end

USE_NODE nodes[0]
TEST "kadalu pool create pool5 server1:/exports/pool5/s1 server2:/exports/pool5/s2 server3:/exports/pool5/s3 --auto-add-nodes --distribute"
TEST "kadalu pool stop pool5 --mode=script"
TEST "kadalu pool delete pool5 --mode=script"

# Tests for pool re-use usecase
def create_pool_and_get_id(cmd)
    out = TEST cmd
    last_line = out.strip.split("\n")[-1]
    pool_id = last_line.nil? ? "" : last_line.split(":")[-1].strip
    pool_id
end

# Can ignore --auto-add-nodes since it already created & not deleted.
# Case 1
# Create pool6 & delete it. Reuse the same path with --pool-id for pool7.
USE_NODE nodes[0]
pool_id = create_pool_and_get_id("kadalu pool create pool6 server1:/exports/pool6/s1 server2:/exports/pool6/s2 server3:/exports/pool6/s3 --no-start --distribute")
TEST "kadalu pool delete pool6 --mode=script"
new_pool_id = create_pool_and_get_id("kadalu pool create pool7 server1:/exports/pool6/s1 server2:/exports/pool6/s2 server3:/exports/pool6/s3 --no-start --pool-id=#{pool_id} --distribute")
EQUAL pool_id, new_pool_id, "Checking if pool-id are equal after pool6 is reused with --pool-id in pool7"
TEST "kadalu pool delete pool7 --mode=script"

# Case 2
# Create pool8. Create pool9 with --pool-id of active pool8.
pool_id = create_pool_and_get_id("kadalu pool create pool8 server1:/exports/pool8/s1 server2:/exports/pool8/s2 server3:/exports/pool8/s3 --no-start --distribute")
TEST 1, "kadalu pool create pool9 server1:/exports/pool9/s1 server2:/exports/pool9/s2 server3:/exports/pool9/s3 --no-start --pool-id=#{pool_id} --distribute"
TEST "kadalu pool delete pool8 --mode=script"

# Case 3
# Create pool10 with full storage-unit directory
TEST "kadalu pool create pool10 server1:/exports/pool10/s1 --no-start"
TEST "kadalu pool delete pool10 --mode=script"

# Case 4 [Negation of Case1]
# Create pool11 & delete it. Create pool12 with same path of unactive pool11 without --pool-id.
TEST "kadalu pool create pool11 server1:/exports/pool11/s1 server2:/exports/pool11/s2 server3:/exports/pool11/s3 --no-start --distribute"
TEST "kadalu pool delete pool11 --mode=script"
TEST 1, "kadalu pool create pool12 server1:/exports/pool11/s1 server2:/exports/pool11/s2 server3:/exports/pool11/s3 --no-start --distribute"

# Case 5
# Create pool13 with fresh path & no xattrs using --pool-id with wrong format. [Check for matching format of pool-id with uuid]
TEST 1, "kadalu pool create pool13 server1:/exports/pool12/s1 server2:/exports/pool12/s2 server3:/exports/pool12/s3 --no-start --pool-id=123-456-789 --distribute"


# Tests for restarting of all services on node-reboot
TEST "kadalu pool create pool14 server1:/exports/pool14/s1 server2:/exports/pool14/s2 server3:/exports/pool14/s3 --distribute"
nodes.each do |node|
  USE_NODE node
  puts TEST "ps aux | grep 'glusterfsd'"
  EQUAL "1", (TEST "ps aux | grep '[g]lusterfsd'| wc -l").strip, "Check for equal number of services[brick-processes]"
  puts TEST "kill $(pidof 'glusterfsd')"
  TEST "systemctl restart kadalu-mgr"
  TEST "sleep 5"
  puts TEST "ps aux | grep 'glusterfsd'"
  EQUAL "1", (TEST "ps aux | grep '[g]lusterfsd'| wc -l").strip, "Check for equal number of services[brick-processes]"
end

USE_NODE nodes[0]
TEST "kadalu pool stop pool14 --mode=script"
TEST "kadalu pool delete pool14 --mode=script"

# Volfile Server tests
# pool create with known Storage unit port
TEST "mkdir -p /exports/pool_volfile/s1"
TEST "kadalu pool create pool_volfile server1:5007:/exports/pool_volfile/s1"
puts TEST "ls /var/lib/kadalu/volfiles"

# Mount the Pool
TEST "mkdir -p /mnt/pool_volfile"
TEST "glusterfs -s server1:5007 --volfile-id pool_volfile -l/tmp/volspec.log /mnt/pool_volfile"
puts TEST "df /mnt/pool_volfile"

# Use mount command (Different options)
# Using Mgr URL
TEST "mkdir -p /mnt/pool_volfile_1"
puts TEST "mount -t kadalu http://server1:3000:/pool_volfile /mnt/pool_volfile_1"
puts TEST "df /mnt/pool_volfile_1"

# TODO: Mgr URL from ENV
TEST "mkdir -p /mnt/pool_volfile_2"
puts TEST "mount -t kadalu /pool_volfile /mnt/pool_volfile_2"
puts TEST "df /mnt/pool_volfile_2"

# Using Storage Unit URL directly
TEST "mkdir -p /mnt/pool_volfile_3"
puts TEST "mount -t kadalu server1:5007:/pool_volfile /mnt/pool_volfile_3"
puts TEST "df /mnt/pool_volfile_3"

# Using Volfile Server option
TEST "mkdir -p /mnt/pool_volfile_4"
puts TEST "mount -t kadalu -o \"volfile-server=server1:5007\" /pool_volfile /mnt/pool_volfile_4"
puts TEST "df /mnt/pool_volfile_4"

# Using Volfile Servers option
TEST "mkdir -p /mnt/pool_volfile_5"
puts TEST "mount -t kadalu -o \"volfile-servers=server1:5007 server1:5007\" /pool_volfile /mnt/pool_volfile_5"
puts TEST "df /mnt/pool_volfile_5"

# Using Volfile Path option
TEST "mkdir -p /mnt/pool_volfile_6"
puts TEST "mount -t kadalu /var/lib/kadalu/volfiles/pool_volfile.vol /mnt/pool_volfile_6"
puts TEST "df /mnt/pool_volfile_6"

TEST "umount /mnt/pool_volfile_*"

# Change option using pool set
TEST "kadalu pool set pool_volfile diagnostics.client-log-level DEBUG"
TEST "sleep 5"

# Print the mount log to see if the option changed is reflected
puts TEST "cat /tmp/volspec.log"
TEST "grep -q \"Volume file changed\" /tmp/volspec.log"

TEST "umount /mnt/pool_volfile"

TEST "kadalu pool stop pool_volfile --mode=script"
TEST "kadalu pool delete pool_volfile --mode=script"

# Tests for Backup & Restore
TEST "kadalu pool create pool19 server1:/exports/pool19/s1 server2:/exports/pool19/s2 server3:/exports/pool19/s3 --distribute"
USE_NODE nodes[0]
TEST "kadalu config-snapshot create snap1"
puts TEST "kadalu config-snapshot list"

TEST "systemctl stop kadalu-mgr"
TEST "rm -rf /var/lib/kadalu/meta /var/lib/kadalu/info"

TEST "kadalu config-snapshot restore snap1 --mode=script"

TEST "systemctl start kadalu-mgr"

TEST "kadalu pool stop pool19 --mode=script"
TEST "kadalu pool delete pool19 --mode=script"

# Tests for pool expansion
# Distribute
TEST "kadalu pool create pool15 server1:/exports/pool15/s1 server2:/exports/pool15/s2 server3:/exports/pool15/s3 --distribute"
TEST "mkdir -p /mnt/pool15"
puts TEST "kadalu mount pool15 /mnt/pool15"
puts TEST "df /mnt/pool15"
TEST "mkdir /mnt/pool15/d1 /mnt/pool15/d2 /mnt/pool15/d3"
TEST "touch /mnt/pool15/d1/f{1..9}"
TEST "touch /mnt/pool15/d2/f{1..9}"
TEST "touch /mnt/pool15/d3/f{1..9}"
TEST "kadalu pool expand pool15 server1:/exports/pool15/s1_e server2:/exports/pool15/s2_e server3:/exports/pool15/s3_e"
TEST "sleep 3"

EQUAL "3", (TEST "ls /exports/pool15/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/pool15/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/pool15/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit"

USE_NODE nodes[0]
TEST "kadalu rebalance start pool15"
TEST "sleep 3"

EQUAL "3", (TEST "ls /exports/pool15/s1/d1/f3 /exports/pool15/s1/d2/f3 /exports/pool15/s1/d3/f3 | wc -l").strip, "Check for migrate-data in server1 s1 unit pool15"
EQUAL "5", (TEST "ls /exports/pool15/s1_e/d1/f4 /exports/pool15/s1_e/d2/f1 /exports/pool15/s1_e/d2/f5 /exports/pool15/s1_e/d3/f1 /exports/pool15/s1_e/d3/f5 | wc -l").strip, "Check for migrate-data in server1 s1_e unit"

USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/pool15/s2/d1/f2 /exports/pool15/s2/d2/f2 /exports/pool15/s2/d3/f2 | wc -l").strip, "Check for migrate-data in server2 s2 unit pool15"
EQUAL "9", (TEST "ls /exports/pool15/s2_e/d1/f6 /exports/pool15/s2_e/d1/f7 /exports/pool15/s2_e/d1/f9 /exports/pool15/s2_e/d2/f6 /exports/pool15/s2_e/d2/f7 /exports/pool15/s2_e/d2/f9 /exports/pool15/s2_e/d3/f6 /exports/pool15/s2_e/d3/f7 /exports/pool15/s2_e/d3/f9 | wc -l
").strip, "Check for migrate-data in server2 s2_e unit"

USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/pool15/s3/d1/f8 /exports/pool15/s3/d2/f4 /exports/pool15/s3/d3/f4 | wc -l ").strip, "Check for migrate-data in server3 s3 unit pool15"
EQUAL "4", (TEST "ls /exports/pool15/s3_e/d1/f1 /exports/pool15/s3_e/d1/f5 /exports/pool15/s3_e/d2/f8 /exports/pool15/s3_e/d3/f8 | wc -l").strip, "Check for migrate-data in server3 s3_e unit"

USE_NODE nodes[0]

TEST "kadalu rebalance status pool15"
TEST "kadalu rebalance status pool15 --detail"

TEST "umount /mnt/pool15"
TEST "rmdir /mnt/pool15"
TEST "kadalu pool stop pool15 --mode=script"
TEST "kadalu pool delete pool15 --mode=script"

# Replicate
TEST "kadalu pool create pool16 replica server1:/exports/pool16/s1 server2:/exports/pool16/s2 server3:/exports/pool16/s3"
TEST "mkdir -p /mnt/pool16"
puts TEST "kadalu mount pool16 /mnt/pool16"
puts TEST "df /mnt/pool16"
TEST "mkdir /mnt/pool16/d1 /mnt/pool16/d2 /mnt/pool16/d3"
TEST "touch /mnt/pool16/d1/f{1..9}"
TEST "touch /mnt/pool16/d2/f{1..9}"
TEST "touch /mnt/pool16/d3/f{1..9}"

TEST "kadalu pool expand pool16 replica server1:/exports/pool16/s1_e server2:/exports/pool16/s2_e server3:/exports/pool16/s3_e"

EQUAL "3", (TEST "ls /exports/pool16/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit pool16"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/pool16/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit pool16"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/pool16/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit pool16"

USE_NODE nodes[0]
TEST "kadalu rebalance start pool16"
TEST "sleep 3"

EQUAL "5", (TEST "ls /exports/pool16/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit pool16"

EQUAL "4", (TEST "ls /exports/pool16/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit pool16"

USE_NODE nodes[1]
EQUAL "5", (TEST "ls /exports/pool16/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit pool16"

EQUAL "4", (TEST "ls /exports/pool16/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit pool16"

USE_NODE nodes[2]
EQUAL "5", (TEST "ls /exports/pool16/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit pool16"
EQUAL "4", (TEST "ls /exports/pool16/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit pool16"

EQUAL "4", (TEST "ls /exports/pool16/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit pool16"
EQUAL "5", (TEST "ls /exports/pool16/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit pool16"

USE_NODE nodes[0]
TEST "umount /mnt/pool16"
TEST "rmdir /mnt/pool16"

TEST "kadalu pool stop pool16 --mode=script"
TEST "kadalu pool delete pool16 --mode=script"

# Distributed Replicate
TEST "kadalu pool create pool17 --distribute replica server1:/exports/pool17/s1 server2:/exports/pool17/s2 server3:/exports/pool17/s3 replica server1:/exports/pool17/s4 server2:/exports/pool17/s5 server3:/exports/pool17/s6"
TEST "mkdir -p /mnt/pool17"
puts TEST "kadalu mount pool17 /mnt/pool17"
puts TEST "df /mnt/pool17"
TEST "mkdir /mnt/pool17/d1 /mnt/pool17/d2 /mnt/pool17/d3"
TEST "touch /mnt/pool17/d1/f{1..9}"
TEST "touch /mnt/pool17/d2/f{1..9}"
TEST "touch /mnt/pool17/d3/f{1..9}"

TEST "kadalu pool expand pool17 replica server1:/exports/pool17/s1_e server2:/exports/pool17/s2_e server3:/exports/pool17/s3_e replica server1:/exports/pool17/s4_e server2:/exports/pool17/s5_e server3:/exports/pool17/s6_e"

EQUAL "3", (TEST "ls /exports/pool17/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s4_e/* -d | wc -l").strip, "Check for fix-layout in server1 s4 unit pool17"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/pool17/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s5_e/* -d | wc -l").strip, "Check for fix-layout in server2 s5 unit pool17"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/pool17/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s6_e/* -d | wc -l").strip, "Check for fix-layout in server3 s6 unit pool17"

USE_NODE nodes[0]
TEST "kadalu rebalance start pool17"
TEST "sleep 3"

EQUAL "2", (TEST "ls /exports/pool17/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s4/d1/ | wc -l").strip, "Check for migrate-data in server1 s4/d1 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s4/d2/ | wc -l").strip, "Check for migrate-data in server1 s4/d2 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s4/d3/ | wc -l").strip, "Check for migrate-data in server1 s4/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit pool17"

EQUAL "3", (TEST "ls /exports/pool17/s4_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s4_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s4_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s4_e/d3 unit pool17"

USE_NODE nodes[1]
EQUAL "2", (TEST "ls /exports/pool17/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s5/d1/ | wc -l").strip, "Check for migrate-data in server2 s5/d1 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s5/d2/ | wc -l").strip, "Check for migrate-data in server2 s5/d2 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s5/d3/ | wc -l").strip, "Check for migrate-data in server2 s5/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit pool17"

EQUAL "3", (TEST "ls /exports/pool17/s5_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s5_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s5_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s5_e/d3 unit pool17"

USE_NODE nodes[2]
EQUAL "2", (TEST "ls /exports/pool17/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s6/d1/ | wc -l").strip, "Check for migrate-data in server3 s6/d1 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s6/d2/ | wc -l").strip, "Check for migrate-data in server3 s6/d2 unit pool17"
EQUAL "3", (TEST "ls /exports/pool17/s6/d3/ | wc -l").strip, "Check for migrate-data in server3 s6/d3 unit pool17"

EQUAL "2", (TEST "ls /exports/pool17/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit pool17"

EQUAL "3", (TEST "ls /exports/pool17/s6_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d1 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s6_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d2 unit pool17"
EQUAL "2", (TEST "ls /exports/pool17/s6_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s6_e/d3 unit pool17"

USE_NODE nodes[0]
TEST "umount /mnt/pool17"
TEST "rmdir /mnt/pool17"

TEST "kadalu pool stop pool17 --mode=script"
TEST "kadalu pool delete pool17 --mode=script"

# Disperse
TEST "kadalu pool create pool18 data server1:/exports/pool18/s1 server2:/exports/pool18/s2 redundancy server3:/exports/pool18/s3"
TEST "mkdir -p /mnt/pool18"
puts TEST "kadalu mount pool18 /mnt/pool18"
puts TEST "df /mnt/pool18"
TEST "mkdir /mnt/pool18/d1 /mnt/pool18/d2 /mnt/pool18/d3"
TEST "touch /mnt/pool18/d1/f{1..9}"
TEST "touch /mnt/pool18/d2/f{1..9}"
TEST "touch /mnt/pool18/d3/f{1..9}"

TEST "kadalu pool expand pool18 data server1:/exports/pool18/s1_e server2:/exports/pool18/s2_e redundancy server3:/exports/pool18/s3_e"

EQUAL "3", (TEST "ls /exports/pool18/s1_e/* -d | wc -l").strip, "Check for fix-layout in server1 s1 unit pool18"
USE_NODE nodes[1]
EQUAL "3", (TEST "ls /exports/pool18/s2_e/* -d | wc -l").strip, "Check for fix-layout in server2 s2 unit pool18"
USE_NODE nodes[2]
EQUAL "3", (TEST "ls /exports/pool18/s3_e/* -d | wc -l").strip, "Check for fix-layout in server3 s3 unit pool18"

USE_NODE nodes[0]
TEST "kadalu rebalance start pool18"
TEST "sleep 3"

EQUAL "5", (TEST "ls /exports/pool18/s1/d1/ | wc -l").strip, "Check for migrate-data in server1 s1/d1 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s1/d2/ | wc -l").strip, "Check for migrate-data in server1 s1/d2 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s1/d3/ | wc -l").strip, "Check for migrate-data in server1 s1/d3 unit pool18"

EQUAL "4", (TEST "ls /exports/pool18/s1_e/d1/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d1 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s1_e/d2/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d2 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s1_e/d3/ | wc -l").strip, "Check for migrate-data in server1 s1_e/d3 unit pool18"

USE_NODE nodes[1]
EQUAL "5", (TEST "ls /exports/pool18/s2/d1/ | wc -l").strip, "Check for migrate-data in server2 s2/d1 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s2/d2/ | wc -l").strip, "Check for migrate-data in server2 s2/d2 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s2/d3/ | wc -l").strip, "Check for migrate-data in server2 s2/d3 unit pool18"

EQUAL "4", (TEST "ls /exports/pool18/s2_e/d1/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d1 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s2_e/d2/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d2 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s2_e/d3/ | wc -l").strip, "Check for migrate-data in server2 s2_e/d3 unit pool18"

USE_NODE nodes[2]
EQUAL "5", (TEST "ls /exports/pool18/s3/d1/ | wc -l").strip, "Check for migrate-data in server3 s3/d1 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s3/d2/ | wc -l").strip, "Check for migrate-data in server3 s3/d2 unit pool18"
EQUAL "4", (TEST "ls /exports/pool18/s3/d3/ | wc -l").strip, "Check for migrate-data in server3 s3/d3 unit pool18"

EQUAL "4", (TEST "ls /exports/pool18/s3_e/d1/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d1 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s3_e/d2/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d2 unit pool18"
EQUAL "5", (TEST "ls /exports/pool18/s3_e/d3/ | wc -l").strip, "Check for migrate-data in server3 s3_e/d3 unit pool18"

USE_NODE nodes[0]
TEST "umount /mnt/pool18"
TEST "rmdir /mnt/pool18"

TEST "kadalu pool stop pool18 --mode=script"
TEST "kadalu pool delete pool18 --mode=script"

puts TEST "kadalu pool list --json"

TEST "kadalu config-snapshot create snap2"
puts TEST "kadalu config-snapshot list"
TEST "kadalu config-snapshot delete snap2 --mode=script"
puts TEST "kadalu config-snapshot list"

# Tests for renaming of pool
USE_NODE nodes[0]
TEST "kadalu pool create pool20a server1:/exports/pool20a/s1 --no-start"
TEST "kadalu pool create pool20b server1:/exports/pool20b/s1 server2:/exports/pool20b/s2 server3:/exports/pool20b/s3 --no-start --distribute"
TEST 1, "kadalu pool rename pool20b pool20b"

TEST "kadalu pool delete pool20a --mode=script"
TEST 0, "kadalu pool rename pool20b pool20a"

puts TEST "kadalu node list"

TEST "kadalu pool delete pool20a --mode=script"

nodes.each do |node|
  USE_NODE nodes[0]
  puts TEST "kadalu node remove #{node} --mode=script"
end

puts TEST "kadalu user logout"

nodes.each do |node|
  USE_NODE node
  puts TEST "cat /var/log/kadalu/mgr.log"
  puts TEST "cat /var/log/kadalu/storage_units/*;"
end
