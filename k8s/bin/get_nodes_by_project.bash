#!/bin/bash

source init.conf
source ${deployconf} 
projectId=$1


if [[ $projectId == "" ]] 
then
    printf "need projectId" 
    exit 1
fi


output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --request GET "${opsMgrExtUrl1}/api/public/v1.0/groups/${projectId}/hosts?pretty=true" )

printf "%s" "$output" | jq '.results[]| .hostname,.systemInfo'
exit 0
