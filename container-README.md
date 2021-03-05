# Kadalu Storage Management

## Build Containers

Builder base

```
docker build . --tag docker.io/kadalu-storage/builder -f Dockerfile.builder
```

Build node container

```
docker build . --tag docker.io/kadalu-storage/node -f Dockerfile.node
```

Build Server container

```
docker build . --tag docker.io/kadalu-storage/server -f Dockerfile.server
```

## Usage

Create Kadalu network

```
docker network create kadalu
```

Run one instance of `kadalu-storage/server` container and spawn multiple instance of `kadalu-storage/node` containers as required.

```
docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --cap-add SYS_ADMIN --name kadalu-control --network kadalu kadalu-storage/server
```

Login and check if `kadalu-server` is running

```
docker exec -it kadalu-control /bin/bash
root@e044bf61ea76:/# systemctl status kadalu-server
● kadalu-server.service - Kadalu Storage Server
     Loaded: loaded (/lib/systemd/system/kadalu-server.service; enabled; vendor preset: enabled)
     Active: active (running) since Fri 2021-03-05 08:01:45 UTC; 11min ago
   Main PID: 34 (kadalu-server)
      Tasks: 2 (limit: 2227)
     Memory: 1.8M
     CGroup: /docker/e044bf61ea7657640deb13ffaf6dfcd9a2178f48c7a226f5ccd03597663213af/system.slice/kadalu-server.service
             └─34 /usr/sbin/kadalu-server

Mar 05 08:01:45 e044bf61ea76 systemd[1]: Started Kadalu Storage Server.
Mar 05 08:01:45 e044bf61ea76 kadalu-server[34]: [development] Kemal is ready to lead at http://0.0.0.0:3000
```

```
docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --cap-add SYS_ADMIN --name node1 --network kadalu --hostname node1.kadalu kadalu-storage/node
docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --cap-add SYS_ADMIN --name node2 --network kadalu --hostname node2.kadalu kadalu-storage/node
```

Login to check if `kadalu-node` service is running

```
docker exec -it node1 /bin/bash
root@c6c8292b9107:/# systemctl status kadalu-node
● kadalu-node.service - Kadalu Storage node agent
     Loaded: loaded (/lib/systemd/system/kadalu-node.service; enabled; vendor preset: enabled)
     Active: active (running) since Fri 2021-03-05 07:49:34 UTC; 26min ago
   Main PID: 33 (kadalu-node)
      Tasks: 2 (limit: 2227)
     Memory: 800.0K
     CGroup: /docker/c6c8292b91070eec9de137ca99dc5f209d9a65dbbf3deee30d6bd8f13bd8ba6a/system.slice/kadalu-node.service
             └─33 /usr/sbin/kadalu-node

Mar 05 07:49:34 c6c8292b9107 systemd[1]: Started Kadalu Storage node agent.
Mar 05 07:49:34 c6c8292b9107 kadalu-node[33]: [development] Kemal is ready to lead at http://0.0.0.0:3001
```

## Cluster Create

Login to `kadalu-control` and create user and Cluster as required.

```
$ docker exec -it kadalu-control /bin/bash
```

```
# Known issue, not able to set this env automatically(`http://$(hostname):3000`)
$ export KADALU_MGMT_SERVER=http://kadalu-control.kadalu:3000
$ kadalu register admin admin@example.com
Enter password:
User registered successfully.
ID: 40e4a2c9-caf2-4a1b-92c3-3c9181e7986d
$
$ kadalu login admin@example.com
Enter password:
Successfully logged in to Kadalu Storage Server.
App ID: fc8d1cc4-3379-4c30-a946-1523d4509b26

Token saved to `~/.kadalu/app.json` Run `kadalu logout` to logout from the Server or delete the `~/.kadalu/app.json` file.

$ kadalu cluster create mycluster
Cluster created successfully.
ID: 2861aa91-a89b-46ab-8cf8-1ee3a4a6fe53

Saved as default Cluster
$
$ kadalu cluster list
 ID                                    Name
*2861aa91-a89b-46ab-8cf8-1ee3a4a6fe53  mycluster
```

Now Join the nodes

```
$ kadalu node join http://node1.kadalu:3001
Node joined successfully.
ID: b8567223-2881-4988-8280-84edf890ef59
$
$ kadalu node join http://node2.kadalu:3001
Node joined successfully.
ID: cbcaecc9-710a-451e-b023-c0a89493d43b
$
$ kadalu node list
ID                                    Name                       Endpoint
b8567223-2881-4988-8280-84edf890ef59  node1.kadalu               http://node1.kadalu:3001
cbcaecc9-710a-451e-b023-c0a89493d43b  node2.kadalu               http://node2.kadalu:3001
```

Now Login to node containers and create brick directories(Note: Brick Volume need to be specified while starting the node container)

```
$ docker exec -it node1 /bin/bash
root@node1:/# mkdir -p /bricks/gvol1
root@node1:/# exit
```

```
$ docker exec -it node2 /bin/bash
root@node2:/# mkdir -p /bricks/gvol1
root@node2:/# exit
```

Now login to control container and create and start the Volume

```
$ docker exec -it kadalu-control /bin/bash
root@kadalu-control:/# kadalu volume create gvol1 node1.kadalu:/bricks/gvol1/b1 node2.kadalu:/bricks/gvol1/b2
Volume creation request sent successfully.
Task ID: 3315b28c-02a4-4490-83b1-c68c4fa62a27
root@kadalu-control:/#
root@kadalu-control:/# kadalu volume list
ID                                    Name            Type            State
c576818e-8c20-48c5-b92b-603a1aa37e11  gvol1           Distribute      Created
root@kadalu-control:/#
root@kadalu-control:/# kadalu volume start gvol1
Volume start request sent successfully.
Task ID: 41cd2c7d-95aa-433b-8e8f-f4c0a60e85fa
root@kadalu-control:/#
root@kadalu-control:/# kadalu volume list
ID                                    Name            Type            State
c576818e-8c20-48c5-b92b-603a1aa37e11  gvol1           Distribute      Started
```

## TODO:

* Add Volumes for `/var/lib/kadalu` for each Node containers
* Add Volume for `kadalu-storage/server`(For Sqlite db and other things)
* Set the required environment variables
* How to communicate between containers(Self-heal daemon requires to connect to other storage nodes, kadalu-node agent needs to connect to Kadalu Server/Control plane)
* Access brick directories inside `kadalu-storage/node` container(Dynamic access when new brick added)
* Add volume for log files or use syslog?
* Set Proper Hostname for `kadalu-storage/node` containers.
* Changes required in Dockerfile to build for Arm (Refer [build_arm64_static.sh](./build_arm64_static.sh))
