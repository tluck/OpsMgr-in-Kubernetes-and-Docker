#!/bin/bash

. init.conf

# update/create configmap with OrgId
#sed -e "s|ORGID|${orgId}|g" -e "s|OPSMGRURL|${opsMgrUrl}|g"  ops-mgr-operator-configmap-my-replica-set.yaml | kubectl apply -f -

kubectl delete configmap my-replica-set
kubectl create configmap my-replica-set \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=MyReplicaSet"  #Optional
 # --from-literal="orgId={$orgId}>" #Optional

kubectl get configmaps -n mongodb

# create replica set
kubectl apply -f ops-mgr-resource-my-replica-set.yaml

while true
do
    kubectl get mongodb/my-replica-set
    kubectl get mongodb/my-replica-set -o json| jq '.status.phase, .status.message'
    status=$( kubectl wait --for condition=ready pod/my-replica-set-2 )
    if [[ $? == 0 ]];
    then
        printf "%s\n" $status
        break
    fi
    sleep 10
done
