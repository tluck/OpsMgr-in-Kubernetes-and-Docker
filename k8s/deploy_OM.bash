#!/bin/bash

. init.conf

# metrics
kubectl apply -f /opt/Source/metrics-server/components.yaml 

# create namespace and mongo operator
kubectl create namespace mongodb
kubectl config set-context $(kubectl config current-context) --namespace=mongodb
kubectl apply -f crds.yaml
kubectl apply -f mongodb-enterprise.yaml
kubectl get all -n mongodb
kubectl describe pods -n mongodb

# create secret - for main admin user
kubectl delete secret admin-user-credentials
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"

# apply resource file to build OpsManager
kubectl apply -f ops-mgr-resource.yaml

while true
do
    kubectl get om 
    eval status=$( kubectl get om -o json | jq .items[0].status.opsManager.phase )
    if [[ $status == "Running" ]];
    then
        break
    fi
    sleep 10
done

opsMgrUrl=$( kubectl get om -o json | jq .items[0].status.opsManager.url )
cat init.conf |sed -e '/opsMgrUrl/d' > new
echo  opsMgrUrl="$opsMgrUrl"
echo  opsMgrUrl="$opsMgrUrl" >> new
mv new init.conf