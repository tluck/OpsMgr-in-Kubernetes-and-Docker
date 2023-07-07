#!/bin/bash

# argument if set to 1 will skip creating new certs for OM and the App DB
while getopts 'odsgth' opt
do
  case "$opt" in
    o)   OM="true"; Clusters="false" ;;
    d)   Clusters="true"; OM="false" ;;
    s|g) skip="-g" ;;
    t)   demo="-t" ;;
    ?|h)
      echo "Usage: $(basename $0) [-o ] [-s|-g] [-t]"
      echo "     use -o to deploy the OM resource"
      echo "     use -d to deploy the Cluster resources"
      echo "     use -t for k8s clusters with limited memory such as docker or minikube, etc "
      echo "     use -s -g to skip cert generation"
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

[[ "${context}" == "docker"* || "${context}" == "minikube" || "${context}" == "colima" ]] && demo="-t"

if [[ $OM == 'true' ]]
then
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
(set -x;
deploy_Operator.bash
)
[[ $? != 0 ]] && exit 1

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."

if [[ "${demo}"  == "-t" ]]
then
# [[ "${context}" == "docker"* ]] && docker pull "quay.io/mongodb/mongodb-enterprise-ops-manager:$omVersion" # issue with docker not (re)pulling the image
(set -x; 
deploy_OM.bash $skip $demo # [-n name] [-g] [-c cpu] [-m memory] [-d disk] [-v version] 
)
else
(set -x; deploy_OM.bash $skip -n "${omName}" -c "1.00" -m "4Gi" -d "40Gi" -v "$omVersion" )
fi

if [[ ${omBackup} == true ]]
then
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1 DB for OM ..."
if [[ "${demo}"  == "-t" ]]
then
(set -x;
    deploy_Cluster.bash -n "${omName}-oplog" -c "0.33" -m "300Mi"         -v "${appdbVersion}" ${skip}
)
else
(set -x;
    deploy_Cluster.bash -n "${omName}-oplog" -c "0.50" -m "2Gi" -d "40Gi" -v "${appdbVersion}" ${skip}
)
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup BlockStore1 DB for OM ..."
if [[ "${demo}"  == "-t" ]]
then
(set -x;
    deploy_Cluster.bash -n "${omName}-blockstore" -c "0.33" -m "300Mi"         -v "${appdbVersion}" ${skip}
)
else
(set -x;
    deploy_Cluster.bash -n "${omName}-blockstore" -c "0.50" -m "2Gi" -d "40Gi" -v "${appdbVersion}" ${skip}
)
fi
fi
fi # OM
[[ $OM == 'true' && $Clusters == 'false' ]] && exit

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a custom Org to put your projects in ..."
# Create the Org and put the orgId info in custom.conf
(set -x
deploy_org.bash -o "${orgName}" # -o newOrgName
)
test -e custom.conf && source custom.conf
orgId="${orgName}_orgId"
orgId="${!orgId}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with a splitHorizon configuration for External access ..."
if [[ "${demo}"  == "-t" ]]
then
(set -x
    deploy_Cluster.bash -n "myreplicaset" -e -l "${ldapType}" -c "0.50" -m "400Mi"         -v "6.0.5-ent" -o "${orgId}" -p "myProject1" ${skip}
)
else
(set -x
    deploy_Cluster.bash -n "myreplicaset" -e -l "${ldapType}" -c "1.00" -m "4Gi" -d "20Gi" -v "6.0.5-ent" -o "${orgId}" -p "myProject1" ${skip}
)
fi
cluster1="myProject1-myreplicaset"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
if [[ "${demo}"  == "-t" ]]
then
    printf "\n%s\n" " **** skipping sharded deployment - not enough resources ***"
    # deploy_Cluster.bash -n "mysharded" -l "${ldapType}" -c "0.33" -m "400Mi" -d "1Gi" -s "1" -r "1" -v "${mdbVersion}" -o "${orgId}" -p "myProject2" ${skip}
else
(set -x
    deploy_Cluster.bash -n "mysharded" -l "${ldapType}" -c "0.50" -m "2Gi"   -d "4Gi" -s "2" -r "2" -v "${mdbVersion}" -o "${orgId}" -p "myProject2" ${skip}
)
    cluster2="myProject2-mysharded"

fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update init.conf with IPs and put k8s internal hostnames in /etc/hosts ..."
update_initconf_hostnames.bash -o "${omName}" -r "${cluster1}" -s "${cluster2}"

date
