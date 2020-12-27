## Development Setup

Install Crystal

```
$ curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt-get install build-essential crystal
```

Install the dependencies and build the moana-server

```
$ cd server
$ shards install
$ export PATH=$PATH:$(pwd)/bin
$ shards build
```

Start the moana-server service,

```
$ moana-server
```
