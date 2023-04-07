#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:v:a:c:m:d:bgth' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    v) omVer="$OPTARG" ;;
    a) appdbVer="$OPTARG" ;;
    c) rscpu="$OPTARG" ;;
    m) rsmem="$OPTARG" ;;
    d) rsdsk="$OPTARG" ;;
    b) omBackup="true" ;;
    g) skipMakeCerts=1 ;;
    t) demo=1 ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-v omVersion] [-a appdbVersion] [-c cpu] [-m memory] [-d disk] [-g] [-t]"
      echo "     use -t for k8s clusters with limited memory such as docker or minikube, etc "
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
    ommemlim=${ommemlim:-"3Gi"}
    ommemreq=${ommemreq:-"3Gi"}
    bdcpu=${bdcpu:-"0.75"}
    bdmemlim=${bdmemlim:-"3Gi"}
    bdmemreq=${bdmemreq:-"2Gi"}
    bddsk=${bddsk:-"4Gi"}
    rscpu=${rscpu:-"0.25"}
    rsmem=${rsmem:-"400Mi"}
    rsdsk=${rsdsk:-"2Gi"}
else
    replace="NOTHING "
    omcpu=${omcpu:-"4.00"}
    ommemlim=${ommemlim:-"16Gi"}
    ommemreq=${ommemreq:-"8Gi"}
    bdcpu=${bdcpu:-"4.00"}
    bdmemlim=${bdmemlim:-"16Gi"}
    bdmemreq=${bdmemreq:-"8Gi"}
    bddsk=${bddsk:-"100Gi"}
    rscpu=${rscpu:-"4.00"}
    rsmem=${rsmem:-"16Gi"}
    rsdsk=${rsdsk:-"50Gi"}
fi

omVer="${omVer:-$omVersion}"
omBackup="${omBackup:-false}"
appdbVer="${appdbVer:-$appdbVersion}"
skipMakeCerts=${skipMakeCerts:-0}

printf "\n"
printf "%s\n" "Deploying OM Application   with $ommemlim Maximum Memory, $ommemreq Requested Memory, and $omcpu Cores"
printf "%s\n" "Deploying OM ApplicationDB with $rsmem Maximum Memory, $rsmem Requested Memory, $rscpu Cores, and $rsdsk Disk"
[[ $omBackup == "true" ]] && 
printf "%s\n" "Deploying OM Backup Daemon with $bdmemlim Maximum Memory, $bdmemreq Requested Memory, $bdcpu Cores, and $bddsk Disk"
printf "\n"

# Create the credentials for main admin user
kubectl delete secret         admin-user-credentials > /dev/null 2>&1
kubectl create secret generic admin-user-credentials \
    --from-literal=Username="${user}" \
    --from-literal=Password="${password}" \
    --from-literal=FirstName="${firstName}" \
    --from-literal=LastName="${lastName}"

tlsc="#TLS "
if [[ ${tls} == 1 ]]
then
    if [[ ${skipMakeCerts} == 0 ]]
    then
    printf "%s\n" "Making various certs for OM and the OM AppDB ..."
    # Create certs for OM and App-db
    rm "${PWD}/certs/${name}-[svc,db]".* "${PWD}/certs/queryable-backup.pem" > /dev/null 2>&1
    "${PWD}/certs/make_OM_certs.bash" ${name}
    # create appdb cert request
    kubectl apply -f "${PWD}/certs/certs_${name}-db-cert.yaml" 
    # For enablement of TLS (https) - provide certs and certificate authority
    # <prefix>-<metadata.name>-cert - need the specific keyname server.pem and queryable-backup.pem
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert \
        --from-file="server.pem=${PWD}/certs/${name}-svc.pem" \
        --from-file="${PWD}/certs/queryable-backup.pem" 
    # Configmap used for OM to get the CA - need specific keynames ca-pem and mms-ca.crt
    kubectl delete configmap ${name}-ca > /dev/null 2>&1
    kubectl create configmap ${name}-ca \
        --from-file="ca-pem=${PWD}/certs/ca.pem" \
        --from-file="mms-ca.crt=${PWD}/certs/ca.pem" 
    fi
tlsr=""
else
tlsr="$tlsc"
    if [[ ${skipMakeCerts} == 0 ]]
    then
    # <prefix>-<metadata.name>-cert
    kubectl delete secret         ${name}-cert > /dev/null 2>&1
    kubectl create secret generic ${name}-cert \
        --from-file="${PWD}/certs/queryable-backup.pem"
    fi
fi

mdbom="mdbom_${name}.yaml"

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
    -e "s/RSCPU/$rscpu/" \
    -e "s/RSMEM/$rsmem/" \
    -e "s/RSDISK/$rsdsk/" \
    -e "s/OMCPU/$omcpu/" \
    -e "s/OMMEMLIM/$ommemlim/" \
    -e "s/OMMEMREQ/$ommemreq/" \
    -e "s/OMBACKUP/$omBackup/" \
    -e "s/BDCPU/$bdcpu/" \
    -e "s/BDMEMLIM/$bdmemlim/" \
    -e "s/BDMEMREQ/$bdmemreq/" \
    -e "s/BDDISK/$bddsk/" \
    -e "s/#NP  /$NP/" \
    -e "s/#LB  /$LB/" \
    -e "s/$tlsc/$tlsr/" \
    -e "s/$replace//" \
    -e "s/NAME/$name/g" > "${mdbom}"

#  Deploy OpsManager resources
kubectl apply -f "${mdbom}"

# remove any certificate requests
kubectl delete certificaterequest $( kubectl get certificaterequest -o name | grep "${name}" ) > /dev/null 2>&1

# Monitor the progress until the OpsMgr app is ready
printf "\n%s\n" "Monitoring the progress of resource om/${name} ..."
sleep 10
while true
do
    sleep 15
    kubectl get om/${name}
    pstatus=$( kubectl get om/${name} -o jsonpath={.status.opsManager.phase} )
    message=$( kubectl get om/${name} -o jsonpath={.status.opsManager.message} )
    printf "%s\n" "status.opsManager.message: $message"
    if [[ "$pstatus" == "Running" ]];
    then
        break
    fi
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

# this is critical to get the name and IP for OM for the rest of the deployment
update_initconf_hostnames.bash -o ${name}

exit 0
