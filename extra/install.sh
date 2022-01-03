#!/bin/bash

curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o /tmp/kadalu
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-mgr.service -o /tmp/kadalu-mgr.service
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/mount.kadalu -o /tmp/mount.kadalu

install -m 700 /tmp/kadalu-mgr.service /lib/systemd/system/
install /tmp/kadalu /usr/sbin/kadalu
install /tmp/mount.kadalu /sbin/mount.kadalu
