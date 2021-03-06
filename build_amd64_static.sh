#!/bin/bash
VERSION=${VERSION-devel}
CMDS="
apk add --update --no-cache --force-overwrite \
    sqlite-dev sqlite-static
cd server
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/kadalu-server bin/kadalu-server-amd64
cd ../node
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/kadalu-node bin/kadalu-node-amd64
cd ../cli
time -v shards install --production
VERSION=${VERSION} time -v shards build --static --release --stats --time
mv bin/kadalu bin/kadalu-amd64
"

docker run --rm -it -v $PWD:/workspace -w /workspace crystallang/crystal:0.36.1-alpine /bin/sh -c "$CMDS"
