#!/bin/bash

source init.conf

project=${1:-MYREPLICASET}

pid=$( curl --silent --user "${publicApiKey}:${privateApiKey}" --digest \
 --header "Accept: application/json" \
 --header "Content-Type: application/json" \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/groups/byName/${project}?pretty=true" |jq .id )

#pid=$( cat p.json| jq .id )
projectId=$( eval printf $pid)

jobid=$( curl --silent --user "${publicKey}:${privateKey}" --digest \
 --header "Accept: application/json" \
 --header "Content-Type: application/json" \
 --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups/${projectId}/logCollectionJobs?pretty=true" \
 --data '
   {
     "resourceType": "REPLICASET",
     "resourceName": "myreplicaset",
     "redacted": false,
     "sizeRequestedPerFileBytes": 10000000,
     "logTypes": [ "MONGODB" ]
   }' )

printf "%s" "$jobid"

curl --silent --user "${publicKey}:${privateKey}" --digest \
 --header "Accept: application/json" \
 --header "Content-Type: application/json" \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/groups/${projectId}/logCollectionJobs?pretty=true" 

# -o log-req.json \

