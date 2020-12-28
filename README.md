# Moana

## Install (Server, Node agent and CLI)

Download the latest release with the command

```
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/moana-server-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o moana-server
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/moana-node-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o moana-node
curl -L https://github.com/kadalu/moana/releases/download/0.1.0/moana-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o moana
```

Make the `moana-server`, `moana-node` and `moana` as binary executable.

```
chmod +x ./moana-server
chmod +x ./moana-node
chmod +x ./moana
```

Move the binaries into your PATH.

```
sudo mv ./moana-server ./moana-node ./moana /usr/local/bin/
```

## Usage:

Start the Moana Server(in any one server or cloud)

```
$ moana-server
```

Start the Moana node agent in all Storage nodes.

```
$ # Create Required directories in the node
$ mkdir /var/lib/moana \
    /var/run/moana \
    /var/lib/moana/volfiles \
    /var/log/moana
$ # Copy Systemd unit template file
$ cp extra/kadalu-brick@.service /lib/systemd/system/
$ # Copy glusterfsd wrapper script
$ cp extra/kadalu-brick /usr/sbin/
$ # Start the Node agent
$ sudo moana-node
```

Run CLI from any node.

```
$ export MOANA_URL=http://moana-server-url:3000
$ moana cluster list
```

## Create and view the Cluster

```
$ moana cluster create mycluster
Cluster created successfully.
ID: 230da85c-82fd-43a1-a517-fd6d67bce827

Saved as default Cluster

$ moana cluster list
 ID                                    Name
*230da85c-82fd-43a1-a517-fd6d67bce827  mycluster
```

## Request a node to join the Cluster

```
$ # moana node join <endpoint>
$ moana node join http://node1.example.com:3001
Node joined successfully.
ID: 894de25c-70b2-48c5-8c18-188440d3953a

$ moana node list
ID                                    Name                       Endpoint
894de25c-70b2-48c5-8c18-188440d3953a  node1.example.com          http://node1.example.com:3001
```

**Note**: The endpoint should be reachable from CLI and also for other nodes of the Cluster.

## Create a Volume

```
$ mkdir /bricks
$ moana volume create gvol1 node1.example.com:/bricks/b1
Volume creation request sent successfully.
Task ID: 0f8ea18a-bbd2-403a-b752-ea3fce74e8c6
```

Volume create request will be handled by Moana Task framework, respective node agent will pick up the Volume create task and internally sends Volume create request to all participating nodes. Node agent will also update the Task status to Moana Server. States of each task are:

* Queued - When assigned to a node, but Task is not yet picked up.
* Received - Task is received by the Node and execution is pending
* Completed/Failed - Task is complete or failed.

Check the state of the task using,

```
$ moana task list
Task ID                               State       Assigned To                            Type
0f8ea18a-bbd2-403a-b752-ea3fce74e8c6  Completed   894de25c-70b2-48c5-8c18-188440d3953a   volume_create
```

Once the task is complete, Volume list will show the Volume details

```
$ moana volume list
ID                                    Name            Type            State
97a7546b-5ab5-45b0-9861-acd9b6097519  gvol1           Distribute      Created
```
