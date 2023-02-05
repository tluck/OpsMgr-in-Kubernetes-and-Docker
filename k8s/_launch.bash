#!/bin/bash

# argument if set to 1 will skip creating new certs for OM and the App DB
skipMakeCerts=${1:-0} 

d=$( dirname "$0" )
cd "${d}"
source init.conf

#which jq > /dev/null
#if [[ $? != 0 ]]
#then
#    printf "%s\n" "Exiting - Missing jq tool - run: brew install jq"
#    exit 1
#fi

which cfssl > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing cloudformation certificiate tools - install cfssl and cfssljson"
    exit 1
fi

which kubectl > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing kubectl tool - (brew) install kubernetes-cli"
    exit 1
fi

kubectl api-resources > /dev/null 2>&1
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Check kubectl or cluster readiness"
    exit 1
fi

date
printf "\n%s\n" "__________________________________________________________________________________________"
context=$( kubectl config current-context )
printf "\n%s\n" "Using context: ${context}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
deploy_Operator.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
if [[ ${skipMakeCerts} = 1 || ${skipMakeCerts} == "-s" ]]
then
    skip="-s"
fi
if [[ "${context}" == "docker-desktop" ]]
then
docker pull "quay.io/mongodb/mongodb-enterprise-ops-manager:$omVersion" # issue with docker not (re)pulling the image
deploy_OM.bash -n "opsmanager" $skip  # [-n name] [-c cpu] [-m memory] [-d disk] [-v version] [-p] [-s]
else
deploy_OM.bash -n "opsmanager" $skip -c 0.5 -m 1Gi -d 4Gi -v "$omVersion"
fi

#printf "\n%s\n" "__________________________________________________________________________________________"
#printf "%s\n" "Create the first Org in OM ..."
#deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "opsmanager-oplog"      -c "0.33" -m "300Mi"        -v "$appdbVersion"
else
    deploy_Database.bash -n "opsmanager-oplog"      -c "0.50" -m "2Gi"          -v "$appdbVersion"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "opsmanager-blockstore" -c "0.33" -m "300Mi"        -v "$appdbVersion"
else
    deploy_Database.bash -n "opsmanager-blockstore" -c "0.50" -m "2Gi"          -v "$appdbVersion"
fi


printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "myreplicaset" -l "${ldapType}" -c "0.50" -m "400Mi"        -v "6.0.1-ent"
    replicasetName="myreplicaset"
else
    deploy_Database.bash -n "myreplicaset" -l "${ldapType}" -c "1.00" -m "4Gi" -d "4Gi" -v "6.0.1-ent"
    replicasetName="myreplicaset"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
if [[ "${context}" == "docker-desktop" ]]
then
    printf "\n%s\n" " **** skipping sharded deployment - not enough resources ***"
    # deploy_DatabaseSharded.bash -n "mysharded"    -c "0.33" -m "400Mi"        -s "1"        -v "$mdbVersion"
else

    deploy_DatabaseSharded.bash -n "mysharded"      -c "1.00" -m "2Gi" -d "4Gi" -s "2" -r "2" -v "$mdbVersion"
    shardedName="mysharded"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
update_initconf_hostnames.bash "opsmanager" "$replicasetName" "$shardedName"

date
