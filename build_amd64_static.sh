#!/bin/bash
VERSION=${VERSION-devel}
CMDS="
apk add --update --no-cache --force-overwrite \
    sqlite-dev sqlite-static
cd server
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/moana-server bin/moana-server-amd64
cd ../node
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/moana-node bin/moana-node-amd64
cd ../cli
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/moana bin/moana-amd64
"

docker run --rm -it -v $PWD:/workspace -w /workspace crystallang/crystal:0.35.1-alpine /bin/sh -c "$CMDS"
