#!/bin/bash

set -Eeuo pipefail

# start ops mgr automation agent
#dpkg --install /shareddata/mongodb-mms-automation-agent-manager_10.14.12.6411-1_amd64.ubuntu1604.deb
cp /shareddata/automation-agent.config /etc/mongodb-mms/automation-agent.config
cp /shareddata/mongod.conf /etc/mongod.conf
gosu mongodb mongod -f /etc/mongod.conf
gosu mongodb /opt/mongodb-mms-automation/bin/mongodb-mms-automation-agent --config=/etc/mongodb-mms/automation-agent.config &

sleep infinity
