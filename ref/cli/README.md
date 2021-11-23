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

Install the dependencies

```
$ cd cli
$ shards install
```

Build the CLI

```
$ shards build
```

Export the Moana URL and use the CLI from `bin/moana`

```
$ export KADALU_MGMT_SERVER=http://localhost:4000
$ export PATH=$PATH:$(pwd)/bin
$ kadalu cluster list
```
