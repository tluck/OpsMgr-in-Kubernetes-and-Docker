#!/bin/bash

# argument if set to 1 will skipCertGen creating new certs for OM and the App DB
while getopts 'odsgth' opt
do
  case "$opt" in
    o)   OM="true"; Clusters="false" ;;
    d)   Clusters="true"; OM="false" ;;
    s|g) skipCertGen="-g" ;;
    t)   demo="-t" ;;
    ?|h)
      echo "Usage: $(basename $0) [-o ] [-s|-g] [-t]"
      echo "     use -o to deploy the OM resource"
      echo "     use -d to deploy the Cluster resources"
      echo "     use -t for k8s clusters with limited memory such as docker or minikube, etc "
      echo "     use -s -g to skipCertGen cert generation"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

OM=${OM:-true}
Clusters=${Clusters:-true}

d=$( dirname "$0" )
cd "${d}"
source init.conf

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

[[ -e deploy.conf ]] && rm deploy.conf

date
printf "\n%s\n" "__________________________________________________________________________________________"
context=$( kubectl config current-context )
printf "\n%s\n" "Using context: ${context}"

options="prod"
if [[ "${context}" == "docker"* || "${context}" == "minikube" || "${context}" == "colima" || ${demo} ]] 
then
    export demo="1"
    options="test"
    if [[ ${serviceType} != "NodePort" ]]
    then
        printf "Setting serviceType to NodePort\n"
        serviceType="NodePort"
    fi
    if [[ ${clusterDomain} != "cluster.local" ]]
    then
        printf "Setting clusterDomain to cluster.local\n"
        clusterDomain="cluster.local"
    fi
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
(set -x; deploy_Operator.bash)
[[ $? != 0 ]] && exit 1

if [[ ${OM} == true ]]
then
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
date
    test="-t ${skipCertGen}" # [-n name] [-g] [-c cpu] [-m memory] [-d disk] [-v version] 
    prod="-n ${omName} -c 1.00 -m 4Gi -d 40Gi -v ${omVersion} ${skipCertGen}"
# [[ "${context}" == "docker"* ]] && docker pull "quay.io/mongodb/mongodb-enterprise-ops-manager:$omVersion" # issue with docker not (re)pulling the image
(set -x; deploy_OM.bash ${!options})

if [[ ${omBackup} == true ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    # get the API key stored in a secret to find the AppDB orgId
    get_key.bash
    orgInfo=( $( get_org.bash -o ${omName}-db ) )
    orgId=${orgInfo[1]}
    if [[ "${orgId}" == none ]]
    then
        printf "\n%s\n" "* * * Error - orgId is missing"
        exit 1
    fi
    # put these resources in the same org as the AppDB
    printf "Using Organization: ${omName}-db with orgId: ${orgId} for the OM resources\n"
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Create the Backup Oplog DB for OM ..."
    date
    test="-n ${omName}-oplog -v ${appdbVersion} -c 0.33 -m 300Mi         -o ${orgId} ${skipCertGen}"
    prod="-n ${omName}-oplog -v ${appdbVersion} -c 0.50 -m 2.0Gi -d 40Gi -o ${orgId} ${skipCertGen}"
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> deploy.conf

    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Create the Backup BlockStore DB for OM ..."
    date
    test="-n ${omName}-blockstore -v ${appdbVersion} -c 0.33 -m 300Mi         -o ${orgId} ${skipCertGen}"
    prod="-n ${omName}-blockstore -v ${appdbVersion} -c 1.00 -m 4.0Gi -d 40Gi -o ${orgId} ${skipCertGen}"
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> deploy.conf
fi # backup true
fi # OM
[[ ${OM} == true && ${Clusters} == false ]] && exit

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a specific Organization to put your Deployment projects in ..."
date
# Create the Org and put the orgId info in deploy.conf
(set -x; deploy_org.bash -o "${deploymentOrgName}" ) # -o newOrgName

test -e deploy.conf && source deploy.conf
# get the orgId value out of the variable named like myDeployment_orgId
orgId="${deploymentOrgName//-/_}_orgId"
orgId="${!orgId}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
date
projectName="myProject1"
name="myreplicaset"
test="-n ${name} -v 7.0.4-ent -c 0.50 -m 400Mi         -o ${orgId} -p ${projectName} ${skipCertGen} -l ${ldapType} -e horizon"
prod="-n ${name} -v 7.0.4-ent -c 1.00 -m 4.0Gi -d 20Gi -o ${orgId} -p ${projectName} ${skipCertGen} -l ${ldapType} -e horizon"
# source deploy.conf; deploy_Cluster.bash -n "myreplicaset" -v "6.0.11-ent" -c "0.50" -m "400Mi" -d "1Gi"  -o "$myDeployment_orgId" -p "myProject1" -l "ldap" -e horizon
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> deploy.conf
cluster1="${projectName}-${name}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
date
projectName="myProject2"
name="mysharded"
prod="-n ${name} -v ${mdbVersion} -c 0.50 -m 2Gi -d 4Gi -s 2 -r 2 -l ${ldapType} -o ${orgId} -p ${projectName} ${skipCertGen} -e mongos"
if [[ ${demo} ]]
then
    printf "\n%s\n" " *** skipping sharded deployment - not enough resources ***"
else
# source deploy.conf; deploy_Cluster.bash -n "mysharded" -c "0.33" -m "400Mi" -d "1Gi" -s "1" -r "1" -l "ldap" -o "${myDeployment_orgId}" -p "myProject2" -g
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> deploy.conf
cluster2="${projectName}-${name}"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
(set -x; update_initconf_hostnames.bash -o "${omName}" -r "${cluster1}" -s "${cluster2}")

date
