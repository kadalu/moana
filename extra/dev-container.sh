#!/bin/bash

docker run -d -v /sys/fs/cgroup/:/sys/fs/cgroup:ro --privileged -v $PWD:/src -w /src --name kadalu-dev --hostname kadalu-dev kadalu/storage-node
