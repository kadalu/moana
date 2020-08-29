
## Development Setup (Linux)


## Creating the projects(Onetime)

Moana Server

```
$ amber new --minimal -t ecr -d pg moana-server
```

Moana Node Service

```
$ amber new --minimal -t ecr -d sqlite moana-node
```

Moana CLI

```
$ mkdir cli
$ cd cli
$ shards init
```
