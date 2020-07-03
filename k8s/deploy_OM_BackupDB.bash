#!/bin/bash

. init.conf

# update/create configmap with OrgId
#sed -e "s|ORGID|${orgId}|g" -e "s|OPSMGRURL|${opsMgrUrl}|g"  ops-mgr-operator-configmap-ops-mgr-backup.yaml | kubectl apply -f -

kubectl delete configmap ops-mgr-backup
kubectl create configmap ops-mgr-backup \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=OpsMgrBackup"  #Optional
 # --from-literal="orgId={orgId}" #Optional

kubectl get configmaps -n mongodb

# create replica set
kubectl apply -f ops-mgr-resource-ops-mgr-backup.yaml 

while true
do
    kubectl get mongodb/ops-mgr-backup
    kubectl get mongodb/ops-mgr-backup -o json| jq '.status.phase, .status.message'
    status=$( kubectl wait --for condition=ready pod/ops-mgr-backup-2 )
    if [[ $? == 0 ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 10
done
