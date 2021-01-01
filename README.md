# Kadalu Storage Management - Moana

## Install (Server, Node agent and CLI)

Download the latest release with the command

```
curl -L https://github.com/kadalu/moana/releases/download/0.2.0/kadalu-server-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu-server
curl -L https://github.com/kadalu/moana/releases/download/0.2.0/kadalu-node-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu-node
curl -L https://github.com/kadalu/moana/releases/download/0.2.0/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu
```

Make the `kadalu-server`, `kadalu-node` and `kadalu` as binary executable.

```
chmod +x ./kadalu-server
chmod +x ./kadalu-node
chmod +x ./kadalu
```

Move the binaries into your PATH.

```
sudo mv ./kadalu-server ./kadalu-node ./kadalu /usr/local/bin/
```

## Usage:

Start the Kadalu Management Server(in any one server or cloud)

```
$ kadalu-server
```

Start the node agent in all Storage nodes.

```
$ # Create Required directories in the node
$ mkdir -p /var/lib/kadalu \
    /var/run/kadalu \
    /var/lib/kadalu/volfiles \
    /var/log/kadalu
$ # Copy Systemd unit template file
$ cp extra/kadalu-brick@.service /lib/systemd/system/
$ # Copy glusterfsd wrapper script
$ cp extra/kadalu-brick /usr/sbin/
$ # Start the Node agent
$ sudo kadalu-node
```

If `glusterfsd` is installed in different directory than `/usr/sbin` then import the environment variable as below.

```
$ systemctl set-environment GLUSTERFSD=/usr/local/sbin/glusterfsd
```

Run CLI from any node.

```
$ export KADALU_MGMT_SERVER=http://kadalu-server-url:3000
$ kadalu cluster list
```

## Create and view the Cluster

```
$ kadalu cluster create mycluster
Cluster created successfully.
ID: 230da85c-82fd-43a1-a517-fd6d67bce827

Saved as default Cluster

$ kadalu cluster list
 ID                                    Name
*230da85c-82fd-43a1-a517-fd6d67bce827  mycluster
```

## Request a node to join the Cluster

```
$ # kadalu node join <endpoint>
$ kadalu node join http://node1.example.com:3001
Node joined successfully.
ID: 894de25c-70b2-48c5-8c18-188440d3953a

$ kadalu node list
ID                                    Name                       Endpoint
894de25c-70b2-48c5-8c18-188440d3953a  node1.example.com          http://node1.example.com:3001
```

**Note**: The endpoint should be reachable from CLI and also for other nodes of the Cluster.

## Create a Volume

```
$ mkdir /bricks
$ kadalu volume create gvol1 node1.example.com:/bricks/b1
Volume creation request sent successfully.
Task ID: 0f8ea18a-bbd2-403a-b752-ea3fce74e8c6
```

Volume create request will be handled by Kadalu Storage Task framework, respective node agent will pick up the Volume create task and internally sends Volume create request to all participating nodes. Node agent will also update the Task status to Kadalu Management Server. States of each task are:

* Queued - When assigned to a node, but Task is not yet picked up.
* Received - Task is received by the Node and execution is pending
* Completed/Failed - Task is complete or failed.

Check the state of the task using,

```
$ kadalu task list
Task ID                               State       Assigned To                            Type
0f8ea18a-bbd2-403a-b752-ea3fce74e8c6  Completed   894de25c-70b2-48c5-8c18-188440d3953a   volume_create
```

Once the task is complete, Volume list will show the Volume details

```
$ kadalu volume list
ID                                    Name            Type            State
97a7546b-5ab5-45b0-9861-acd9b6097519  gvol1           Distribute      Created
```

## Start the Volume

Start the newly created Volume using the following command.

```
$ kadalu volume start gvol1
Volume start request sent successfully.
Task ID: 8ef44ebe-12ea-4bf2-b608-9d3cffb8d84a
```

Check the Task status using,

```
$ kadalu task list
Task ID                               State       Assigned To           Type
8ef44ebe-12ea-4bf2-b608-9d3cffb8d84a  Completed   node1.example.com     volume_start
```

## Mount the Volume

Mount script will be introduced soon to automatically download the Volfile and mount. Now use `volfile get` command to download the Volfile and then mount the Volume using `glusterfs` command.

```
$ kadalu volfile get client -v 97a7546b-5ab5-45b0-9861-acd9b6097519 -o /root/gvol1.vol
Volfile downloaded successfully. Volfile saved to /root/gvol1.vol
```

Run `glusterfs` command using the above downloaded Volfile.

```
$ mkdir /mnt/gvol1
$ glusterfs --process-name fuse -l /var/log/kadalu/gvol1.log --volfile-id gvol1 -f /root/gvol1.vol /mnt/gvol1
```

Check if the mount is successful.

```
$ df /mnt/gvol1
Filesystem                          Size   Used Avail Use%   Mounted on
/tmp/gvol1.vol                      10.7G  5.0G 5.7G  46.72% /mnt/gvol1
```

## Hello World

Create a file from the mount and verify that the file is created in both Mount and backend brick.

```
$ echo "Hello World" > /mnt/gvol1/f1
$ cat /mnt/gvol1/f1
Hello World
$ cat /bricks/b1/f1
Hello World
```
