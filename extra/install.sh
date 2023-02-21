#!/bin/bash

curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-`uname -m | sed 's|aarch64|arm64|' | sed 's|x86_64|amd64|'` -o /tmp/kadalu
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/kadalu-mgr.service -o /tmp/kadalu-mgr.service
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/mount.kadalu -o /tmp/mount.kadalu
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/client.vol.j2 -o /tmp/client.vol.j2
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/storage_unit.vol.j2 -o /tmp/storage_unit.vol.j2
curl -fsSL https://github.com/kadalu/moana/releases/latest/download/shd.vol.j2 -o /tmp/shd.vol.j2

install -m 700 /tmp/kadalu-mgr.service /lib/systemd/system/
install /tmp/kadalu /usr/sbin/kadalu
install /tmp/mount.kadalu /sbin/mount.kadalu
install -D -m 700 /tmp/client.vol.j2 /var/lib/kadalu/templates/client.vol.j2
install -D -m 700 /tmp/storage_unit.vol.j2 /var/lib/kadalu/templates/storage_unit.vol.j2
install -D -m 700 /tmp/shd.vol.j2 /var/lib/kadalu/templates/shd.vol.j2
