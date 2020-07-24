#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf

# Create the credentials for main admin user
kubectl delete secret admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"

# for enablement of TLS (https)
cat MyKey.key mms-ca.crt > server.pem
kubectl create secret generic opsmanager-cert --from-file="server.pem"
kubectl create configmap opsmanager-cert-ca --from-file="mms-ca.crt"

#  Deploy OpsManager resources
## kubectl apply -f ops-mgr-resource-ext-np.yaml
kubectl apply -f ops-mgr-resource-ext-lb.yaml
#kubectl apply -f ops-mgr-resource-ext-lb-tls.yaml

# Monitor the progress until the OpsMgr app is ready
while true
do
    kubectl get om 
    eval status=$( kubectl get om -o json | jq .items[0].status.opsManager.phase )
    if [[ $status == "Running" ]];
    then
        break
    fi
    sleep 15
done

# get the OpsMgr URL and internal IP
opsMgrUrl=$( kubectl get om -o json | jq .items[0].status.opsManager.url )
opsMgrIp=$(  kubectl get pod/opsmanager-0 -o json | jq .status.podIP )
eval hostname=$( kubectl get svc/opsmanager-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval ip=$( kubectl get svc/opsmanager-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
if [[ $hostname == "null" ]]
then
    opsMgrUrlExt=http://${ip}:$( kubectl get svc/opsmanager-svc-ext -o json | jq .spec.ports[0].port )
else
    opsMgrUrlExt=http://${hostname}:$( kubectl get svc/opsmanager-svc-ext -o json | jq .spec.ports[0].port )
fi
kubectl get svc/opsmanager-svc-ext

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrIp/d' -e '/opsMgrUrlExt/d' > new
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrIp="$opsMgrIp"             | tee -a new
echo  opsMgrUrlExt=\""$opsMgrUrlExt"\" | tee -a new
mv new init.conf
