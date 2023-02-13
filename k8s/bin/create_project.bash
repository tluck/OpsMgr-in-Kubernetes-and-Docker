#!/bin/bash

source init.conf
source custom.conf

orgId=${1:-myOrg}
projectName=${2:-myProject}

echo '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${projectName}/" -e"s/ORGID/${orgId}/" > data.json
pid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups?pretty=true" \
     --data @data.json )
errorCode=$( printf "%s" "$pid" | jq .errorCode )
rm data.json


if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}Id/d" -e "/${projectName}agentApiKey/d" custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    printf "\n%s\n" "Successfully created Project: $projectName"
    echo  projectName=\"${projectName}\"                                        >> custom.conf
    echo  ${projectName}Id="$(          printf "%s" "$pid" | jq .id )"          >> custom.conf
    echo  ${projectName}agentApiKey="$( printf "%s" "$pid" | jq .agentApiKey )" >> custom.conf
else
    detail=$( printf "%s" "$pid" | jq .detail )
    printf "%s\n" "Error did not create projectName: $detail"
    exit 1
fi
