# -*- mode: ruby -*-

PKG_VERSION = ENV["VERSION"]
ENTRYPOINT = "/bin/sh"
CMD_ARGS = "-c '/sbin/apk add --update --no-cache --force-overwrite sqlite-dev sqlite-static yaml-static libxml2-static xz-static && cd mgr && /usr/bin/shards build --production --release --static --stats --time'"

# Build Amd64
TEST %{docker run --platform=linux/amd64 -i -v `pwd`:/workspace -w /workspace --env VERSION=#{PKG_VERSION} --rm --entrypoint #{ENTRYPOINT} 84codes/crystal:1.7.2-alpine-latest #{CMD_ARGS}}

# Rename release binary
TEST "mv mgr/bin/kadalu mgr/bin/kadalu-amd64"

# Build Arm64
TEST "docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
TEST %{docker run --platform=linux/arm64 -v `pwd`:/workspace -w /workspace --env VERSION=#{PKG_VERSION} -i --rm --entrypoint #{ENTRYPOINT} 84codes/crystal:1.7.2-alpine-latest #{CMD_ARGS}}

# Rename release binary
TEST "mv mgr/bin/kadalu mgr/bin/kadalu-arm64"
