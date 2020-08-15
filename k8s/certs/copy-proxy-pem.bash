#!/bin/bash -x

d=$( dirname "$0" )
cd "${d}"

kubectl cp queryable-backup.pem  mongodb/opsmanager-backup-daemon-0:/opt/queryable-backup.pem
kubectl cp queryable-backup.pem  mongodb/opsmanager-0:/opt/queryable-backup.pem
