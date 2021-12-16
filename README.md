# Kadalu Storage Management - Moana

This README is structured for quickly getting started with the project (from the released binaries). If you want to develop, and contribute to the project, check our [Developer Documentation](./docs/devel/README.adoc)

## Install Moana (Server, Node agent and CLI)

Download and install the latest release with the command

```
curl -L https://github.com/kadalu/moana/releases/latest/download/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o kadalu
install kadalu /usr/sbin/
```

## Usage:

Start the Kadalu Management Server in all the Storage nodes

```
# systemctl enable kadalu-mgr
# systemctl start kadalu-mgr
```

Refer [docs](./docs) for more details.
