#!/bin/bash

source init.conf
source custom.conf

project=${1:-DemoProject}

echo '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${project}/" -e"s/ORGID/${orgId}/" > data.json
pid=$( curl --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups?pretty=true" \
     --data @data.json )
errorCode=$( printf "%s" "$pid" | jq .errorCode )
rm data.json


if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${project}Id/d" -e "/${project}agentApiKey/d" custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    printf "\n%s\n" "Successfully created Project: $project"
    echo  ${project}Id="$(          printf "%s" "$pid" | jq .id )"          | tee -a custom.conf
    echo  ${project}agentApiKey="$( printf "%s" "$pid" | jq .agentApiKey )" | tee -a custom.conf
else
    detail=$( printf "%s" "$pid" | jq .detail )
    printf "%s\n" "Error did not create project: $detail"
    exit 1
fi
