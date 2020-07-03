#!/bin/bash

. init.conf

# metrics
kubectl apply -f /opt/Source/metrics-server/components.yaml 

# Create the namespace and MongoDB Enterprise Operator
kubectl create namespace mongodb
kubectl config set-context $(kubectl config current-context) --namespace=mongodb
kubectl apply -f crds.yaml
kubectl apply -f mongodb-enterprise.yaml
#kubectl get all -n mongodb
#kubectl describe pods -n mongodb

# Create the credentials for main admin user
kubectl delete secret admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"

# Apply resource file to Deploy OpsManager
kubectl apply -f ops-mgr-resource.yaml

# Monitor the progress until the OpsMgr app is ready
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