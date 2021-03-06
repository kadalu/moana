#!/bin/bash

systemctl set-environment GLUSTERFSD=/opt/sbin/glusterfsd
mkdir -p /var/lib/kadalu /var/run/kadalu /var/lib/kadalu/volfiles /var/log/kadalu

exec "$@"
