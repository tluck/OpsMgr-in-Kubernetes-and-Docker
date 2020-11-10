#!/bin/bash

source ./init.conf

project=${1-Project}

echo '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${project}/" -e"s/ORGID/${orgId}/" > data.json
rm project*json > /dev/null 2>&1
curl --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrUrl}/api/public/v1.0/groups?pretty=true" \
     --data @data.json \
     -o project.json > /dev/null 2>&1

if [[ -e "project.json" ]]
then
    cat init.conf |sed -e "/${project}/d" > new
    echo  ${project}Id="$( cat project.json | jq .id )"
    echo  ${project}Id="$( cat project.json | jq .id )" >> new
    echo  ${project}agentApiKey="$( cat project.json | jq .agentApiKey )"
    echo  ${project}agentApiKey="$( cat project.json | jq .agentApiKey )" >> new
    mv new init.conf
else
    printf "%s\n" "Error did not create project"
    exit 1
fi
