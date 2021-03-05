#!/bin/bash

# TODO: This is not working
if [[ -z "${KADALU_MGMT_SERVER}" ]]; then
    export KADALU_MGMT_SERVER=http://$(hostname):3000
fi

exec "$@"
