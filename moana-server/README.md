## Development Setup

Install Crystal

```
$ curl https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt-get install build-essential crystal
```

Install Amber

```
$ sudo apt-get install libreadline-dev libsqlite3-dev libpq-dev libmysqlclient-dev libssl-dev libyaml-dev libpcre3-dev libevent-dev
$ curl -L https://github.com/amberframework/amber/archive/stable.tar.gz | tar xz
$ cd amber-stable/
$ shards install
$ make install
$ cd ..
$ rm -rf amber-stable
```

Install the dependencies

```
$ cd moana-server
$ shards install
```

Postgres Database setup

```
sudo su - postgres
$ psql
postgres-# CREATE DATABASE moana_server_development;
postgres-# CREATE USER postgres;
postgres-# ALTER USER postgres PASSWORD 'secret';
postgres-# ALTER USER postgres WITH SUPERUSER;
```

Export the `DATABASE_URL`

```
$ export DATABASE_URL=postgres://postgres:secret@localhost:5432/moana_server_development
```

Run database migrations

```
$ amber db create migrate
```

Start the moana-node service,

```
$ amber watch
```
