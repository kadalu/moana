# Kadalu Storage Management - Moana

## Install (Server, Node agent and CLI)

Download the latest release with the command

```
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/kadalu-server-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu-server
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/kadalu-node-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu-node
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu
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
