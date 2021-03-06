#!/bin/bash

mkdir -p /etc/systemd/system.conf.d/
mkdir -p /var/lib/kadalu /var/run/kadalu /var/lib/kadalu/volfiles /var/log/kadalu

echo "[Manager]
DefaultEnvironment=$(while read -r Line; do echo -n "$Line " ; done < <(env))
" > /etc/systemd/system.conf.d/myenvironment.conf

exec "$@"
