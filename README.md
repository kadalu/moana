# Kadalu Storage Management - Moana
# Introduction

Moana is a frontend for the Kadalu Storage. Moana provides tools for setting up and managing the Kadalu cluster. Which includes:

    * Creating storage pool and adding nodes to the pool
    * Creating and managing storage volume
among other things.

This README is structured for quickly getting started with the project (from the released binaries). If you want to develop, and contribute to the project, check our [Developer Documentation](./docs/devel/README.adoc)

## Install Moana (Server, Node agent and CLI)

Download and install the latest release with the command

```
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/install.sh | sudo bash -x
```

## Usage:

Start the Kadalu Management Server in all the Storage nodes

```
# systemctl enable kadalu-mgr
# systemctl start kadalu-mgr
```

Refer [docs](./docs) for more details.

## Moana for those who used gluster before

If you are already familiar with gluster project, and how to use the CLI and setup volumes, treat moana as an alternative management layer, which provides CLI and management layer without the complexity of `glusterd` process.

To highlight some key differences:


| property | glusterd | kadalu's moana |
|-----|----|----|
| where it runs | on every server node | server on any one node of users' choice, even outside of server in cloud if required. Node mgr on each server (only connects to server) |
| scale | good upto 32-64 nodes | no limit on number of server nodes |
| access | gluster's custom RPC (using XDR) | RESTful apis |
| CLI | provided | provided |
| brick port management | fixed port range | custom, configurable per brick |
| volume options | no control over bricks | can be extended to control options of bricks, not just server level |
| network | one peer, one IP | lot of control on network identity of nodes, bricks |
| UI | no easy way, with custom rpc being used | easier with RESTful APIs, in roadmap |
| metrics | gluster-prometheus | more granular options, and easier to add more info |


### performance comparisons

* Connections:
  - glusterd: 1 connection for every peer in network.
  - moana: 1 connection per machine (regardless of peers).
  Eg: for a 64 node cluster, in the whole cluster, there would be 4096 connections when glusterd is used, vs, 64 connections when moana is used.


* performance when node reboots: (assume a 64 node cluster, with 100 volumes of 16 bricks each)
  - glusterd: 6300 calls made from the node to validate the correctness. (each call can be of ~1k size, with cpu used for checking md5sum of each volume).
  - moana: 1 call made with few kilo bytes transfered between that node.


