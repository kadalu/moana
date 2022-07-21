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

Check [this link](https://kadalu.tech/gluster-vs-kadalu/) for understanding the key differences before going ahead.

For developers, glusterd uses C lang, where as moana uses crystal lang.