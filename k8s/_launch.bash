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
if [[ ${skipMakeCerts} = 1 || ${skipMakeCerts} == "-s" || ${skipMakeCerts} == "-g" ]]
then
    export skip="-g"
fi

if [[ "${context}" == "docker-desktop" ]]
then
docker pull "quay.io/mongodb/mongodb-enterprise-ops-manager:$omVersion" # issue with docker not (re)pulling the image
deploy_OM.bash $skip  # [-n name] [-g] [-c cpu] [-m memory] [-d disk] [-v version] 
else
deploy_OM.bash $skip -n "${omName}" -c "1.00" -m "4Gi" -d "40Gi" -v "$omVersion"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "${omName}-oplog" $skip      -c "0.33" -m "300Mi"         -v "$appdbVersion"
else
    deploy_Database.bash -n "${omName}-oplog" $skip      -c "0.50" -m "4Gi" -d "40Gi" -v "$appdbVersion"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "${omName}-blockstore" $skip -c "0.33" -m "300Mi"         -v "$appdbVersion"
else
    deploy_Database.bash -n "${omName}-blockstore" $skip -c "0.50" -m "4Gi" -d "40Gi" -v "$appdbVersion"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a custom Org to put your projects in ..."
# Create the Org and put info in custom.conf
bin/deploy_org.bash # -o NewOrgName
source custom.conf

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
projectName="myProject1"
if [[ "${context}" == "docker-desktop" ]]
then
    deploy_Database.bash -n "myreplicaset" $skip -l "${ldapType}" -c "0.50" -m "400Mi"         -v "6.0.1-ent" -o "${orgId}" -p "${projectName}"
    cluster1="${projectName}-myreplicaset"
else
    deploy_Database.bash -n "myreplicaset" $skip -l "${ldapType}" -c "1.00" -m "4Gi" -d "20Gi" -v "6.0.1-ent" -o "${orgId}" -p "${projectName}"
    cluster1="${projectName}-myreplicaset"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
projectName="myProject2"
if [[ "${context}" == "docker-desktop" ]]
then
    printf "\n%s\n" " **** skipping sharded deployment - not enough resources ***"
    # deploy_DatabaseSharded.bash -n "mysharded" $skip -l "${ldapType}" -c "0.33" -m "400Mi"        -s "1"        -v "${mdbVersion}" -o "${orgId}" -p "${projectName}"
else
    deploy_DatabaseSharded.bash -n "mysharded" $skip -l "${ldapType}" -c "1.00" -m "4Gi" -d "4Gi" -s "2" -r "2" -v "${mdbVersion}" -o "${orgId}" -p "${projectName}"
    cluster2="${projectName}-mysharded"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
update_initconf_hostnames.bash "${omName}" "$cluster1" "$cluster2"

date
