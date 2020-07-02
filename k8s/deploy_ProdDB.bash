#!/bin/bash

. init.conf

# create namespace and mongo operator
##kubectl create namespace mongodb
##kubectl config set-context $(kubectl config current-context) --namespace=mongodb
##kubectl apply -f crds.yaml
##kubectl apply -f mongodb-enterprise.yaml
##kubectl get all -n mongodb
##kubectl describe pods -n mongodb

# create secret - API key from OpsManager
#kubectl -n mongodb delete secret admin-public-api-key
#kubectl -n mongodb create secret generic admin-public-api-key \
#    --from-literal="user=${user}" \
#    --from-literal="publicApiKey=${publicApiKey}"

#kubectl describe secrets/admin-public-api-key -n mongodb

# create configmap with OrgId
sed -e "s|ORGID|${orgId}|g" -e "s|OPSMGRURL|${opsMgrUrl}|g"  ops-mgr-operator-configmap.yaml | kubectl apply -f -
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
