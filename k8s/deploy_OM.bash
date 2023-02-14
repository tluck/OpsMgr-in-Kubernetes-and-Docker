#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:v:a:c:m:d:gzh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    v) omVer="$OPTARG" ;;
    a) appdbVer="$OPTARG" ;;
    c) rscpu="$OPTARG" ;;
    m) rsmem="$OPTARG" ;;
    d) rsdsk="$OPTARG" ;;
    g) skipMakeCerts=1 ;;
    t) demo=1 ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-v omVersion] [-a appdbVersion] [-c cpu] [-m memory] [-d disk] [-g] [-t]"
      echo "     use -l for limited memory (docker) "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# for OM App-DB
name=${name:-opsmanager}
if [[ $demo == 1 ]]
then
    replace="#Demo   "
    omcpu=${omcpu:-"0.75"}
    ommem=${ommem:-"3Gi"}
    bdcpu=${bdcpu:-"0.75"}
    bdmem=${bdmem:-"3Gi"}
    bddsk=${bddsk:-"4Gi"}
else
    replace="NOTHING "
    omcpu=${omcpu:-"2.00"}
    ommem=${ommem:-"8Gi"}
    bdcpu=${bdcpu:-"2.00"}
    bdmem=${bdmem:-"8Gi"}
    bddsk=${bddsk:-"40Gi"}
fi

rscpu="${rscpu:-0.25}"
rsmem="${rsmem:-400Mi}"
rsdsk="${rsdsk:-2Gi}"
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
    rm "${PWD}/certs/${name}-[svc,db]".* "${PWD}/certs/queryable-backup.pem" > /dev/null 2>&1
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

if [[ $serviceType == "NodePort" ]]
then 
    LB="#LB  "
else
    NP="#NP   "
fi
# serviceType="LoadBalancer"
# make manifest from template
cat mdbom_template.yaml | sed \
    -e "s/VERSION/$omVer/" \
    -e "s/APPDBVER/$appdbVer/" \
    -e "s/MMSADMINEMAILADDR/$user/" \
    -e "s/MMSEMAIL/$mmsemail/" \
    -e "s/MMSMAILHOSTNAME/$mmsmailhostname/" \
    -e "s/MMSMAILUSERNAME/$mmsmailusername/" \
    -e "s/MMSMAILPASSWORD/$mmsmailpassword/" \
    -e "s/MMSUSERSVCCLASS/$mmsusersvcclass/" \
    -e "s/MMSLDAPBINDDN/$mmsldapbinddn/" \
    -e "s/MMSLDAPBINDPASSWORD/$mmsldapbindpassword/" \
    -e "s/MMSLDAPGLOBALROLEOWNER/$mmsldapglobalroleowner/" \
    -e "s/MMSLDAPGROUPBASEDN/$mmsldapgroupbasedn/" \
    -e "s/MMSLDAPGROUPMEMBER/$mmsldapgroupmember/" \
    -e "s?MMSLDAPURL?$mmsldapurl?" \
    -e "s/MMSLDAPUSERBASEDN/$mmsldapuserbasedn/" \
    -e "s/MMSLDAPUSEREMAIL/$mmsldapuseremail/" \
    -e "s/MMSLDAPUSERFIRSTNAME/$mmsldapuserfirstname/" \
    -e "s/MMSLDAPUSERLASTNAME/$mmsldapuserlastname/" \
    -e "s/MMSLDAPUSERGROUP/$mmsldapusergroup/" \
    -e "s/MMSLDAPUSERSEARCHATTRIBUTE/$mmsldapusersearchattribute/" \
    -e "s/DBUSER/$dbuserlc/" \
    -e "s/RSCPU/$rscpu/" \
    -e "s/RSMEM/$rsmem/" \
    -e "s/RSDISK/$rsdsk/" \
    -e "s/BDCPU/$bdcpu/" \
    -e "s/BDMEM/$bdmem/" \
    -e "s/BDDISK/$bddsk/" \
    -e "s/OMCPU/$omcpu/" \
    -e "s/OMMEM/$ommem/" \
    -e "s/#NP  /$NP/" \
    -e "s/#LB  /$LB/" \
    -e "s/$tlsc/$tlsr/" \
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
n=0
while [ $n -lt 12 ]
do
    kubectl get svc | grep ${name} | grep pending
    if [[ $? = 1 ]]
    then
        kubectl get svc/${name}-svc-ext # svc/${name}-backup svc/${name}-backup-daemon-0
        break
    fi
    printf "%s\n" "Sleeping 15 seconds to allow IP/Hostnames to be created"
    sleep 15
    n=$((n+1))
done
bin/update_initconf_hostnames.bash

exit 0
