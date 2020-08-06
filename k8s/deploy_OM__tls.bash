#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"

# for enablement of TLS (https)
kubectl delete secret         opsmanager-cert > /dev/null 2>&1
kubectl create secret generic opsmanager-cert --from-file="certs/server.pem"
kubectl delete configmap opsmanager-cert-ca > /dev/null 2>&1
kubectl create configmap opsmanager-cert-ca --from-file="certs/mms-ca.crt" # seems to need this filename

# for enablement of TLS on the appdb
kubectl delete secret         appdb-certs > /dev/null 2>&1
kubectl create secret generic appdb-certs \
        --from-file="certs/opsmanager-db-0-pem" \
        --from-file="certs/opsmanager-db-1-pem" \
        --from-file="certs/opsmanager-db-2-pem"
kubectl delete configmap appdb-ca > /dev/null 2>&1
kubectl create configmap appdb-ca --from-file="certs/ca-pem" # seems to need this filename

#  Deploy OpsManager resources
## kubectl apply -f ops-mgr-resource-ext-np.yaml
#kubectl apply -f ops-mgr-resource-ext-lb.yaml
kubectl apply -f ops-mgr-resource-ext-lb-tls.yaml

# Monitor the progress until the OpsMgr app is ready
while true
do
    kubectl get om 
    eval status=$( kubectl get om -o json | jq .items[0].status.opsManager.phase )
    if [[ "$status" == "Running" ]];
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
eval port=$( kubectl get svc/opsmanager-svc-ext -o json | jq .spec.ports[0].port )

http="http"
if [[ $port == "8443" ]]
then
    http="https"
fi

if [[ $hostname == "null" ]]
then
    opsMgrUrlExt=${http}://${ip}:${port}
else
    opsMgrUrlExt=${http}://${hostname}:${port}
fi
kubectl get svc/opsmanager-svc-ext

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrIp/d' -e '/opsMgrUrlExt/d' > new
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrIp="$opsMgrIp"             | tee -a new
echo  opsMgrUrlExt=\""$opsMgrUrlExt"\" | tee -a new
mv new init.conf
