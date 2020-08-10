#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf
name=${1:-opsmanager}
mdbom="mdbom_${name}.yaml"
mdbom_tls="mdbom_${name}_tls.yaml"

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"
  
if [[ ${tls} == 1 ]]
then
# for enablement of TLS (https)
kubectl delete secret         ${name}-cert > /dev/null 2>&1
kubectl create secret generic ${name}-cert --from-file="certs/server.pem" # seems to need this keyname
kubectl delete configmap ${name}-cert-ca > /dev/null 2>&1
kubectl create configmap ${name}-cert-ca --from-file="certs/mms-ca.crt" # seems to need this keyname

# for enablement of TLS on the appdb
kubectl delete secret         appdb-certs > /dev/null 2>&1
kubectl create secret generic appdb-certs \
        --from-file="certs/${name}-db-0-pem" \
        --from-file="certs/${name}-db-1-pem" \
        --from-file="certs/${name}-db-2-pem"
kubectl delete configmap appdb-ca > /dev/null 2>&1
kubectl create configmap appdb-ca --from-file="certs/ca-pem" # seems to need this keyname

#  Deploy OpsManager resources
kubectl apply -f ${mdbom_tls}
else
kubectl apply -f ${mdbom}
fi

# Monitor the progress until the OpsMgr app is ready
while true
do
    kubectl get om 
    eval status=$( kubectl get om -o json | jq .items[0].status.opsManager.phase )
    if [[ "$status" == "Running" ]];
    then
        break
    fi
    kubectl get pods/${name} > /dev/null 2>&1
    if [[ $? == 0 ]]
    then
    # copy queryiable backup pem file to pod
    kubectl cp certs/${name}-proxy-pem mongodb/${name}-0:/mongodb-ops-manager/conf/${name}-proxy-pem
    fi
    sleep 15
done

# get the OpsMgr URL and internal IP
opsMgrUrl=$( kubectl get om -o json | jq .items[0].status.opsManager.url )
opsMgrIp=$(  kubectl get pod/${name}-0 -o json | jq .status.podIP )
eval hostname=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval ip=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
eval port=$( kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].port )

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
kubectl get svc/${name}-svc-ext

# copy queryiable backup pem file to pod
kubectl cp certs/${name}-proxy-server-pem mongodb/${name}-0:/mongodb-ops-manager/conf/${name}-proxy-server-pem

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrIp/d' -e '/opsMgrUrlExt/d' > new
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrIp="$opsMgrIp"             | tee -a new
echo  opsMgrUrlExt=\""$opsMgrUrlExt"\" | tee -a new
mv new init.conf

open "$opsMgrUrlExt"
exit 0