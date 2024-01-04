#!/bin/bash

cluster=${1:-myproject2-mysharded}

shard=${cluster}-0
for p in $(kubectl get pods -o name |grep $shard)
do 
echo ---- $p ---
kubectl exec $p -i -t -c "mongodb-enterprise-database" -- bash -c 'cat $( ls -1 /var/log/mongodb-mms-automation/backup-agent.lo*|grep -v gz) |egrep "Opened backup cursor to | Exiting"' 
done

shard=${cluster}-1
for p in $(kubectl get pods -o name |grep $shard)
do 
echo ---- $p ---
kubectl exec $p -i -t -c "mongodb-enterprise-database" -- bash -c 'cat $( ls -1 /var/log/mongodb-mms-automation/backup-agent.lo*|grep -v gz) |egrep "Opened backup cursor to | Exiting"' 
done

for p in $( kubectl get pods -o name |grep "opsmanager-[012345678]")
do
echo ---- $p ---
kubectl exec $p -i -t -c "mongodb-ops-manager" -- bash -c 'cat $( ls -1 /mongodb-ops-manager/logs/mms0.lo* | grep -v gz ) | grep "backup.jobs"|grep "Snapshot is complete"|grep ect2'
done
