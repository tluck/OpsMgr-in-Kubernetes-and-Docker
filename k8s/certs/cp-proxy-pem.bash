#!/bin/bash
cd  /opt/mongo/OpsMgr/k8s
kubectl cp certs/opsmanager-backup-daemon-0.pem  mongodb/opsmanager-backup-daemon-0:/opt/queryable-backup.pem
kubectl cp certs/opsmanager-backup-daemon-0.pem  mongodb/opsmanager-0:/opt/queryable-backup.pem
