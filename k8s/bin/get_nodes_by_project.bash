#!/bin/bash

source init.conf
source custom.conf 
projectId=$1


if [[ $projectId == "" ]] 
then
    printf "need projectId" 
    exit 1
fi


oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/groups/${projectId}/hosts?pretty=true" )

printf "%s" "$oid" | jq '.results[]| .hostname,.systemInfo'
exit 0
