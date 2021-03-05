#!/bin/bash

systemctl set-environment GLUSTERFSD=/opt/sbin/glusterfsd

exec "$@"
