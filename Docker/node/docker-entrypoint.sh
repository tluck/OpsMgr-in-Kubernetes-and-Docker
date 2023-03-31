#!/bin/bash

set -Eeuo pipefail

arg="${1:-none}"

if [[ "$arg" == "startmdb" ]]
then
    cp /shareddata/mongod.conf /etc/mongod.conf
    gosu mongodb mongod -f /etc/mongod.conf
fi

# start ops mgr automation agent
cp /shareddata/automation-agent.config /etc/mongodb-mms/automation-agent.config
gosu mongodb /opt/mongodb-mms-automation/bin/mongodb-mms-automation-agent --config=/etc/mongodb-mms/automation-agent.config &

sleep infinity
