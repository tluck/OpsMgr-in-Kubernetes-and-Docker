#!/bin/bash

. init.conf
# Set namespace
kubectl config set-context $(kubectl config current-context) --namespace=mongodb

# Create map for OM Org/Project
kubectl delete configmap my-replica-set > /dev/null 2>&1
kubectl create configmap my-replica-set \
  --from-literal="baseUrl=${opsMgrUrl}" \
  --from-literal="projectName=MyReplicaSet"  #Optional
 # --from-literal="orgId={$orgId}>" #Optional
kubectl get configmaps -n mongodb

# create replica set with TLS and Auth
kubectl apply -f ops-mgr-resource-my-replica-set-secure.yaml

sleep 10
# TLS Cert approval
kubectl certificate approve my-replica-set-0.mongodb 
kubectl certificate approve my-replica-set-1.mongodb
kubectl certificate approve my-replica-set-2.mongodb

# Create a db user credentials
kubectl delete secret dbadmin-credentials > /dev/null 2>&1
kubectl create secret generic dbadmin-credentials \
  --from-literal=name="dbAdmin" \
  --from-literal=password="${password}"

# Create the User
kubectl apply -f ops-mgr-resource-database-user-conf.yaml

while true
do
    kubectl get mongodb/my-replica-set
    kubectl get mongodb/my-replica-set -o json| jq '.status.phase, .status.message'
    status=$( kubectl wait --for condition=ready pod/my-replica-set-2 )
    if [[ $? == 0 ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 10
done
