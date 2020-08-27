#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf
name=${1:-opsmanager}
skipcerts=${2:-0}
mdbom="mdbom_${name}.yaml"
mdbom_tls="mdbom_${name}_tls.yaml"

if [[ ${tls} == 1 && ${skipcerts} == 0 ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Getting Certs status..."
    # Get ca.crt and create certs for OM and App-db
    rm certs/${name}*pem
    certs/make_OM_certs.bash ${name}
    ls -1 certs/*pem certs/*crt 
fi

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
  --from-literal=Username="${user}" \
  --from-literal=Password="${password}" \
  --from-literal=FirstName="${firstName}" \
  --from-literal=LastName="${lastName}"
  
if [[ ${tls} == 1 ]]
then
# For enablement of TLS (https) - provide certs and certificate authority
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert --from-file="certs/server.pem" --from-file="certs/queryable-backup.pem" # seems to need server.pem keyname
    kubectl delete configmap ${name}-cert-ca > /dev/null 2>&1
    kubectl create configmap ${name}-cert-ca --from-file="certs/mms-ca.crt" # seems to need this keyname

# For enablement of TLS on the appdb - custom certs
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
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert --from-file="certs/queryable-backup.pem"

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
    sleep 15
done
sleep 10

# get the OpsMgr URL and internal IP
opsMgrUrl=$(     kubectl get om -o json | jq .items[0].status.opsManager.url )
eval hostname=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval opsMgrIp=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
eval port=$(     kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].port )

http="http"
if [[ ${port} == "8443" ]]
then
    http="https"
fi

if [[ ${hostname} == "null" ]]
then
    opsMgrExtUrl=${http}://${ip}:${port}
else
    opsMgrExtUrl=${http}://${hostname}:${port}
    if [[ "${hostname}" != "localhost" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        opsMgrIp=${list[3]}
    else
        opsMgrIp=127.0.0.1
    fi
fi

# expose port 25999 for queryable backup
kubectl apply -f svc_${name}-backup.yaml
kubectl get svc/${name}-svc-ext svc/${name}-backup

# copy queryiable backup pem file to pod
# kubectl cp certs/${name}-backup-daemon-0.pem mongodb/${name}-0:/opt/${name}-proxy.pem
# kubectl cp certs/${name}-backup-daemon-0.pem  mongodb/${name}-backup-daemon-0:/opt/${name}-proxy.pem

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d'  > new
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrExtIp="$opsMgrIp"          | tee -a new
echo  opsMgrExtUrl=\""$opsMgrExtUrl"\" | tee -a new
mv new init.conf

# put internal name in /etc/hosts with externalIP
Misc/update_hostnames.bash

exit 0