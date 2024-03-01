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

OM=${OM:-false}
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

which kubectl-mongodb > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing kubectl-mongodb extension - install kubectl-mongodb"
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
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
(set -x; deploy_mcOperator.bash)
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
printf "#deploy_OM.bash ${!options}\n" >> ${deployconf}

if [[ ${omBackup} == true ]]
then
    # put these resources in the same org as the AppDB
    orgInfo=( $( get_org.bash -o ${omName}-db ) )
    deploymentOrgName=${orgInfo[1]}

    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Create the Backup Oplog DB for OM ..."
    date
    test="-n ${omName}-oplog -v ${appdbVersion} -c 0.33 -m 300Mi         -o ${deploymentOrgName} ${skipCertGen}"
    prod="-n ${omName}-oplog -v ${appdbVersion} -c 0.50 -m 2.0Gi -d 40Gi -o ${deploymentOrgName} ${skipCertGen}"
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> ${deployconf}

    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Create the Backup BlockStore DB for OM ..."
    date
    test="-n ${omName}-blockstore -v ${appdbVersion} -c 0.33 -m 300Mi         -o ${deploymentOrgName} ${skipCertGen}"
    prod="-n ${omName}-blockstore -v ${appdbVersion} -c 1.00 -m 4.0Gi -d 40Gi -o ${deploymentOrgName} ${skipCertGen}"
(set -x; deploy_Cluster.bash ${!options})
printf "#deploy_Cluster.bash ${!options}\n" >> ${deployconf}
fi # backup true
fi # OM
[[ ${OM} == true && ${Clusters} == false ]] && exit

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a specific Organization to put your Deployment projects in ..."
date
# Create the Org and put the deploymentOrgName info in ${deployconf}
(set -x; deploy_org.bash -o "${deploymentOrgName}" ) # -o newOrgName
test -e ${deployconf} && source ${deployconf}
orgId="${deploymentOrgName//-/_}_orgId"
orgId="${!orgId}"

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster with an external domain configuration for External access ..."
date
projectName="myMultiClusterProject1"
name="myreplicaset"
test="-n ${name} -v 6.0.11-ent -c 0.50 -m 400Mi         -o ${deploymentOrgName} -p ${projectName} ${skipCertGen} -e mdb.com"
prod="-n ${name} -v 6.0.11-ent -c 1.00 -m 4.0Gi -d 20Gi -o ${deploymentOrgName} -p ${projectName} ${skipCertGen} -e mdb.com"
# -e horizon is broken at this time
# source ${deployconf}; deploy_Cluster.bash -n "myreplicaset" -v "6.0.11-ent" -c "1.00" -m "4.0Gi" -d "20Gi" -o "myDeployment" -p "myMultiClusterProject1" -e mdb.com
(set -x; deploy_multiCluster.bash ${!options})
printf "#deploy_multiCluster.bash ${!options}\n" >> ${deployconf}

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production ReplicaSet Cluster withOUT configuration for External access ..."
date
projectName="myMultiClusterProject2"
name="myreplicaset"
test="-n ${name} -v 6.0.11-ent -c 0.50 -m 400Mi         -o ${deploymentOrgName} -p ${projectName} ${skipCertGen}"
prod="-n ${name} -v 6.0.11-ent -c 1.00 -m 4.0Gi -d 20Gi -o ${deploymentOrgName} -p ${projectName} ${skipCertGen}"
# -e horizon is broken at this time
# source ${deployconf}; deploy_Cluster.bash -n "myreplicaset" -v "6.0.11-ent" -c "0.50" -m "400Mi" -d "1Gi" -o "myDeployment" -p "myMultiClusterProject2"
(set -x; deploy_multiCluster.bash ${!options})
printf "#deploy_multiCluster.bash ${!options}\n" >> ${deployconf}

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create a Production Sharded Cluster  ..."
date
projectName="myMultiClusterProject2"
name="mysharded"
prod="-n ${name} -v ${mdbVersion} -c 0.50 -m 2Gi -d 4Gi -s 2 -r 2 -l ${ldapType} -o ${deploymentOrgName} -p ${projectName} ${skipCertGen} -e mongos"
if [[ ${demo} ]]
then
    printf "\n%s\n" " *** skipping sharded deployment - not enough resources ***"
else
# source ${deployconf}; deploy_Cluster.bash -n "mysharded" -c "0.33" -m "400Mi" -d "1Gi" -s "1" -r "1" -l "ldap" -o "${myDeployment_deploymentOrgName}" -p "myProject2" -g
    printf "\n%s\n" " *** skipping sharded deployment - not implemented for MC ***"
#(set -x; deploy_Cluster.bash ${!options})
#cluster2="${projectName}-${name}"
fi

date
