#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc:"${d}"/certs:

source init.conf

which jq > /dev/null
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Missing jq tool - run: brew install jq"
    exit 1
fi

kubectl api-resources > /dev/null 2>&1
if [[ $? != 0 ]]
then
    printf "%s\n" "Exiting - Check kubectl or cluster readiness"
    exit 1
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
deploy_Operator.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy SMTP relay and until Running status..."
# Deploy simple SMTP forwarder 
mail/deploy_SMTP.bash

if [[ ${tls} == 1 ]]
then
    printf "\n%s\n" "__________________________________________________________________________________________"
    printf "%s\n" "Getting Certs status..."
    # Get ca.crt and create certs for OM and App-db
    rm certs/ops*pem
    certs/get_ca.crt.bash
    #certs/make_opsmanger_certs.bash
    certs/make_certs.bash opsmanager
    ls -1 certs/*pem certs/*crt 
fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
deploy_OM.bash opsmanager

#printf "\n%s\n" "__________________________________________________________________________________________"
#printf "%s\n" "Create the first Org in OM ..."
#deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1/BlockStore1 DB for OM ..."
deploy_Database.bash ops-mgr-backup

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the 1st Production DB ..."
# deploy_ProdDB.bash
# printf "%s" "Do you need external access to the DB?"
# read -p " [Y/n] " ans <&0 && if [[ ${ans:0:1} == "n" || ${ans:0:1} == "N" ]]; then exit 0; fi

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Generate splitHorizon configuration for External access to Production DB ..."
deploy_Database.bash my-replica-set

