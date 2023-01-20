#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:v:a:c:m:d:sh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    v) omVer="$OPTARG" ;;
    a) appdbVer="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    s) skipMakeCerts=1 ;; 
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-v omVersion][-a appdbVersion] [-c cpu] [-m memory] [-d disk] [-p] [-s]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-opsmanager}
cpu="${cpu:-0.25}"
mem="${mem:-400Mi}"
dsk="${dsk:-2Gi}"
omVer="${omVer:-$omVersion}"
appdbVer="${appdbVer:-$appdbVersion}"
skipMakeCerts=${skipMakeCerts:-0}

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
    --from-literal=Username="${user}" \
    --from-literal=Password="${password}" \
    --from-literal=FirstName="${firstName}" \
    --from-literal=LastName="${lastName}"
  
if [[ ${tls} == 1 && ${skipMakeCerts} == 0 ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Getting Certs status..."
    # Generate CA and create certs for OM and App-db
    rm "${PWD}/certs/${name}"*.* "${PWD}/certs/queryable-backup.pem" > /dev/null 2>&1
    "${PWD}/certs/make_OM_certs.bash" ${name}
    appdb=${name}-db
    "${PWD}/certs/make_db_certs.bash" ${appdb} 
    ls -1 "${PWD}/certs/"*pem "${PWD}/certs/"*crt 
fi

tlsc="#TLS "
if [[ ${tls} == 1 ]]
then
# For enablement of TLS (https) - provide certs and certificate authority
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert \
        --from-file="server.pem=${PWD}/certs/${name}-svc.pem" \
        --from-file="${PWD}/certs/queryable-backup.pem" # need specific keyname server.pem
    # CA used to define the projects configmap and agent ca for OM dbs
    kubectl delete configmap ${name}-ca > /dev/null 2>&1
    kubectl create configmap ${name}-ca \
        --from-file="ca-pem=${PWD}/certs/ca.pem" \
        --from-file="mms-ca.crt=${PWD}/certs/ca.pem" # need specific keynames ca-pem and mms-ca.crt

# For enablement of TLS on the appdb - custom certs
appdb=${name}-db
# Create a secret for the member certs for TLS
kubectl delete secret ${appdb}-cert > /dev/null 2>&1
# sleep 3
# kubectl get secrets
kubectl create secret tls ${appdb}-cert \
    --cert="${PWD}/certs/${appdb}.crt" \
    --key="${PWD}/certs/${appdb}.key"

tlsr=""
else
tlsr="$tlsc"
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert \
        --from-file="${PWD}/certs/queryable-backup.pem"
fi

mdbom="mdbom_${name}.yaml"
dbuserlc=$( printf "$dbuser" | tr '[:upper:]' '[:lower:]' )
context=$( kubectl config current-context )
if [[ "${context}" == "docker-desktop" ]]
then
    replace="#Docker "
else
    replace="#Prod   "
fi
# make manifest from template
cat mdbom_template.yaml | sed \
    -e "s/$tlsc/$tlsr/" \
    -e "s/VERSION/$omVer/" \
    -e "s/APPDBVER/$appdbVer/" \
    -e "s/MEM/$mem/" \
    -e "s/CPU/$cpu/" \
    -e "s/DISK/$dsk/" \
    -e "s/DBUSER/$dbuserlc/" \
    -e "s/MMSADMINEMAILADDR/$user/" \
    -e "s/MMSEMAIL/$mmsemail/" \
    -e "s/MMSMAILHOSTNAME/$mmsmailhostname/" \
    -e "s/MMSMAILUSERNAME/$mmsmailusername/" \
    -e "s/MMSMAILPASSWORD/$mmsmailpassword/" \
    -e "s/$replace//" \
    -e "s/NAME/$name/" > "${mdbom}"

#  Deploy OpsManager resources
kubectl apply -f "${mdbom}"

# Monitor the progress until the OpsMgr app is ready
printf "\n%s\n" "Monitoring the progress of resource om/${name} ..."
sleep 10
while true
do
    kubectl get om/${name}
    pstatus=$( kubectl get om/${name} -o jsonpath={.status.opsManager.phase} )
    message=$( kubectl get om/${name} -o jsonpath={.status.opsManager.message} )
    printf "%s\n" "status.opsManager.message: $message"
    if [[ "$pstatus" == "Running" ]];
    then
        break
    fi
    sleep 15
done

# pre v1.8.2 - fix to expose port 25999 for queryable backup
# kubectl apply -f svc_${name}-backup.yaml
# pre v1.8.2 - fix to get a DNS name for the backup-daemon pod
# kubectl apply -f svc_${name}-backup-daemon.yaml
# list services for OM and QB

# update init.conf and put internal hostnames in /etc/hosts
printf "\n%s\n" "Monitoring the progress of svc ${name} ..."
while true
do
    kubectl get svc | grep ${name} | grep pending
    if [[ $? = 1 ]]
    then
        kubectl get svc/${name}-svc-ext # svc/${name}-backup svc/${name}-backup-daemon-0
        break
    fi
    printf "%s\n" "Sleeping 15 seconds to allow IP/Hostnames to be created"
    sleep 15
done
update_initconf_hostnames.bash

exit 0
