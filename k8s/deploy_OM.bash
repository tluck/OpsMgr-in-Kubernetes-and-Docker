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
    kubectl create secret generic ${name}-cert --from-file="certs/server.pem" --from-file="certs/queryable-backup.pem" # need specific keyname server.pem
    # CA used to define the projects configmap and agent ca for OM dbs
    kubectl delete configmap ${name}-ca > /dev/null 2>&1
    kubectl create configmap ${name}-ca --from-file="certs/ca-pem" --from-file="certs/mms-ca.crt" # need specific keynames ca-pem and mms-ca.crt

# For enablement of TLS on the appdb - custom certs
    kubectl delete secret         appdb-certs > /dev/null 2>&1
    kubectl create secret generic appdb-certs \
            --from-file="certs/${name}-db-0-pem" \
            --from-file="certs/${name}-db-1-pem" \
            --from-file="certs/${name}-db-2-pem"

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

# expose port 25999 for queryable backup
kubectl apply -f svc_${name}-backup.yaml
# list services OM and QB
kubectl get svc/${name}-svc-ext svc/${name}-backup

# update init.conf and put internal hostnames in /etc/hosts
Misc/update_initconf_hostnames.bash

exit 0
