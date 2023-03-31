#!/bin/bash

set -Eeuo pipefail

#cp /shareddata/mongosqld-config.yml /etc
#/mongodb-bi-linux-x86_64-ubuntu2004-v2.14.5/bin/mongosqld install /etc/mongosqld-config.yml #--logPath=/var/log/bi-connector.log  > /var/log/run.log 2>&1
echo Starting mongosqld
/usr/local/bin/start_mongosqld.bash > /var/log/run.out

sleep infinity
