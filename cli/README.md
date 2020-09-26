## Development Setup

Install Crystal

```
$ curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt-get install build-essential crystal
```

Clone the repo

```
$ git clone https://github.com/kadalu/moana.cr.git
$ cd moana.cr
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
$ export MOANA_URL=http://localhost:3000
$ export PATH=$PATH:$(pwd)/bin
$ moana cluster list
```
