#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf

# update/create configmap with OrgId
#sed -e "s|ORGID|${orgId}|g" -e "s|OPSMGRURL|${opsMgrUrl}|g"  ops-mgr-operator-configmap-ops-mgr-backup.yaml | kubectl apply -f -

# Create a map for OM Org/Project
kubectl delete configmap ops-mgr-backup > /dev/null 2>&1
kubectl create configmap ops-mgr-backup \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=OpsMgrBackup" \
  
  #--from-literal="sslMMSCAConfigMap=opsmanager-cert-ca" \
  #--from-literal="sslRequireValidMMSServerCertificates=‘true’"
  # --from-literal="orgId={orgId}" #Optional

# Create the replica set for the Backing DBs
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
    sleep 15
done
