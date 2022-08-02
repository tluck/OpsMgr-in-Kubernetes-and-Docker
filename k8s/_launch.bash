#!/bin/bash

# argument if set to 1 will skip creating new certs for OM and the App DB
skipcerts=${1:-0} 

d=$( dirname "$0" )
cd "${d}"
source init.conf

which jq > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing jq tool - run: brew install jq"
    exit 1
fi

which cfssl > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing cfssl tool - run: brew install cfssl"
    exit 1
fi

kubectl api-resources > /dev/null 2>&1
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Check kubectl or cluster readiness"
    exit 1
fi

context=$( kubectl config current-context )

date

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
deploy_Operator.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy SMTP relay and until Running status..."
# Deploy simple SMTP forwarder to a gmail account.
kubectl get pod smtp > /dev/null 2>&1
if [[ $? = 1 ]]
then
    mail/deploy_SMTP.bash
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
deploy_OM.bash opsmanager ${skipcerts}

#printf "\n%s\n" "__________________________________________________________________________________________"
#printf "%s\n" "Create the first Org in OM ..."
#deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "opsmanager-oplog"      -c "0.33" -m "300Mi"        -v "5.0.9-ent" 
else
    deploy_Database.bash -n "opsmanager-oplog"      -c "0.50" -m "2Gi"          -v "5.0.9-ent"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "opsmanager-blockstore" -c "0.33" -m "300Mi"        -v "5.0.9-ent"
else
    deploy_Database.bash -n "opsmanager-blockstore" -c "0.50" -m "2Gi"          -v "5.0.9-ent"
fi


printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Generate splitHorizon configuration for External access to a Production DB ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "my-replica-set"        -c "0.50" -m "400Mi"        -v "5.0.7-ent"
else
    deploy_Database.bash -n "my-replica-set"        -c "1.00" -m "4Gi" -d "4Gi" -v "5.0.7-ent"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Generate configuration for External access to a Sharded Production DB ..."
if [[ "${context}" == "docker-desktop" ]]
then
    printf "\n%s\n" " **** skipping sharded deployment - not enough resources ***"
else
    deploy_DatabaseSharded.bash  -n "my-sharded"    -c "0.50" -m "2Gi" -s "2" -v "5.0.9-ent"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
Misc/update_initconf_hostnames.bash

date
