#!/bin/bash

source ./init.conf

project=${1:-DemoProject}

echo '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${project}/" -e"s/ORGID/${orgId}/" > data.json
pid=$( curl --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrUrl}/api/public/v1.0/groups?pretty=true" \
     --data @data.json )
errorCode=$( printf "%s" "$pid" | jq .errorCode )
rm data.json

if [[ "${errorCode}" == "null" ]]
then
    initconf=$( sed -e "/${project}Id/d" -e "/${project}agentApiKey/d" init.conf )
    printf "%s\n" "${initconf}" > init.conf
    printf "\n%s\n" "Successfully created Project: $project"
    echo  ${project}Id="$(          printf "%s" "$pid" | jq .id )"          | tee -a init.conf
    echo  ${project}agentApiKey="$( printf "%s" "$pid" | jq .agentApiKey )" | tee -a init.conf
else
    detail=$( printf "%s" "$pid" | jq .detail )
    printf "%s\n" "Error did not create project: $detail"
    exit 1
fi
