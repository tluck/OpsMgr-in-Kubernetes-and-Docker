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

if [[ "${context}" == "docker"* || "${context}" == "minikube" || "${context}" == "colima" || ${demo} ]] 
then
    export demo="1"
    if [[ ${serviceType} != "NodePort" ]]
    then
        printf "Setting serviceType to NodePort\n"
        serviceType="NodePort"
    fi
fi

if [[ ${OM} == true && ${Clusters} == true ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Deploy the Operator ..."
    (set -x; deploy_Operator.bash)
    [[ $? != 0 ]] && exit 1
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
date
if [[ ${OM} == true ]]
then
    if [[ ${demo} ]]
    then
        options=" -t ${skipCertGen}" # [-n name] [-g] [-c cpu] [-m memory] [-d disk] [-v version] 
    else
        options=" -n ${omName} -c 1.00 -m 4Gi -d 40Gi -v ${omVersion} ${skipCertGen}"
    fi
# [[ "${context}" == "docker"* ]] && docker pull "quay.io/mongodb/mongodb-enterprise-ops-manager:$omVersion" # issue with docker not (re)pulling the image
(set -x; deploy_OM.bash ${options})

if [[ ${omBackup} == true ]]
then
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog DB for OM ..."
date
    if [[ ${demo} ]]
    then
        options=" -n ${omName}-oplog -v ${appdbVersion} -c 0.33 -m 300Mi         ${skipCertGen}"
    else
        options=" -n ${omName}-oplog -v ${appdbVersion} -c 0.50 -m 2.0Gi -d 40Gi ${skipCertGen}"
    fi
(set -x; deploy_Cluster.bash ${options})

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore DB for OM ..."
date
    if [[ ${demo} ]]
    then
        options=" -n ${omName}-blockstore -v ${appdbVersion} -c 0.33 -m 300Mi         ${skipCertGen}"
    else
        options=" -n ${omName}-blockstore -v ${appdbVersion} -c 1.00 -m 4.0Gi -d 40Gi ${skipCertGen}"
    fi
(set -x; deploy_Cluster.bash ${options})
fi # backup true
fi # OM
[[ ${OM} == true && ${Clusters} == false ]] && exit

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a specific Organization to put your projects in ..."
date
# Create the Org and put the orgId info in custom.conf
(set -x; deploy_org.bash -o "${orgName}" ) # -o newOrgName

test -e custom.conf && source custom.conf
# get the orgId value out of the variable named like myOrg_orgId
orgId="${orgName}_orgId"
orgId="${!orgId}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
date
projectName="myProject1"
name="myreplicaset"
if [[ ${demo} ]]
then
    options=" -n ${name} -v 6.0.5-ent -c 0.50 -m 400Mi         -e -l ${ldapType} -o ${orgId} -p ${projectName} ${skipCertGen}"
else
    options=" -n ${name} -v 6.0.5-ent -c 1.00 -m 4.0Gi -d 20Gi -e -l ${ldapType} -o ${orgId} -p ${projectName} ${skipCertGen}"
fi
# source custom.conf; deploy_Cluster.bash -n "myreplicaset" -v "6.0.5" -c "0.50" -m "400Mi" -d "1Gi" -e -l "ldap" -o "$myOrg_orgId" -p "myProject1" -g
(set -x; deploy_Cluster.bash ${options})
cluster1="${projectName}-${name}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
date
if [[ ${demo} ]]
then
    printf "\n%s\n" " **** skipCertGenping sharded deployment - not enough resources ***"
else
    name="mysharded"
    projectName="myProject2"
    options=" -n ${name} -v ${mdbVersion} -c 0.50 -m 2Gi -d 4Gi -s 2 -r 2 -l ${ldapType} -o ${orgId} -p ${projectName} ${skipCertGen}"
# source custom.conf; deploy_Cluster.bash -n "mysharded" -c "0.33" -m "400Mi" -d "1Gi" -s "1" -r "1" -l "ldap" -o "${myOrg_orgId}" -p "myProject2" -g
(set -x; deploy_Cluster.bash ${options})
cluster2="${projectName}-${name}"
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
(set -x; update_initconf_hostnames.bash -o "${omName}" -r "${cluster1}" -s "${cluster2}")

date
