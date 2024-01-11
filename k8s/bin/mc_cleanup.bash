#!/usr/bin/env bash

source init.conf

contexts=$(kubectl config get-contexts -o name | grep gke | sort -r)

# kill these processess off
kubectl -n ${namespace}   delete deployment mongodb-enterprise-operator 
kubectl -n ${mcNamespace} delete deployment mongodb-enterprise-operator-multi-cluster 
kubectl -n ${namespace}   exec ${omName}-backup-daemon-0 -i -t -c mongodb-backup-daemon -- kill 1

for context in $contexts
do
    kubectl --context=$context delete namespace ${namespace} &
    kubectl --context=$context delete namespace ${mcNamespace} &
done
