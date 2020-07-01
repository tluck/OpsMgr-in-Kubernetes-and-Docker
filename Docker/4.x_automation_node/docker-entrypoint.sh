#!/bin/bash

set -Eeuo pipefail

# start ops mgr automation agent
cp /shareddata/automation-agent.config /etc/mongodb-mms/automation-agent.config
#gosu mongodb /opt/mongodb-mms-automation/bin/mongodb-mms-automation-agent --config=/etc/mongodb-mms/automation-agent.config >> /var/lib/mongodb-mms-automation/automation-agent-fatal.log 2>&1 &
gosu mongodb /opt/mongodb-mms-automation/bin/mongodb-mms-automation-agent --config=/etc/mongodb-mms/automation-agent.config &

exec "/bin/bash"
