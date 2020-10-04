#!/bin/bash
time docker run --rm -it -v $PWD:/workspace -w /workspace crystallang/crystal:0.35.1-alpine /bin/sh -c 'cd cli && shards install --production && shards build --release --static'
time docker run --rm -it -v $PWD:/workspace -w /workspace crystallang/crystal:0.35.1-alpine /bin/sh -c 'cd moana-server && shards install --production && shards build --release --static'
time docker run --rm -it -v $PWD:/workspace -w /workspace crystallang/crystal:0.35.1-alpine /bin/sh -c 'cd moana-node && shards install --production && shards build --release --static'
