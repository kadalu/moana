# moana-node

Clone the repo

```
$ git clone https://github.com/kadalu/moana.git
$ cd moana.cr
```

Create Required directories in the node

```
$ mkdir /var/lib/moana \
    /var/run/moana \
    /var/lib/moana/volfiles \
    /var/log/moana
```

Copy Systemd unit template file

```
$ cp extra/kadalu-brick@.service /lib/systemd/system/
```

Copy glusterfsd wrapper script

```
$ cp extra/kadalu-brick /usr/sbin/
```

## Development Setup

Install Crystal

```
$ curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt-get install build-essential crystal
```

Clone the repo

```
$ git clone https://github.com/kadalu/moana.git
$ cd moana
```

Install the dependencies and build the moana-node

```
$ cd node
$ shards install
$ export PATH=$PATH:$(pwd)/bin
$ shards build
```

Start the moana-node service,

```
$ moana-node
```

Options available are:

* `NODENAME` - Node name/host name to use with all Volume operations. Default `$(hostname)`
* `PORT` - Port of the service. If `ENDPOINT` is specified then takes the PORT from that. Default value is `4000` if Endpoint also not specified.
* `ENDPOINT` - Endpoint to use for in-cluster communication between nodes. Default is `$(hostname):${PORT}`
* `ENDPOINT_HTTPS` - If `yes` then use `https` for the endpoint URL else use `http`.
* `WORKDIR` - Workdir to save node/cluster configurations once joined to a Cluster. Default is `/var/lib/kadalu`

To run with the above options,

```
$ NODENAME=node1.example.com ENDPOINT=http://node1.local:4001 moana-node
```

Now `moana-node` is ready for getting Join request.
