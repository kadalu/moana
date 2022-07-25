#!/bin/bash

docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged -p 3000:3000 -v $PWD:/src -w /src --name kadalu-dev --hostname kadalu-dev kadalu/storage-node-testing
