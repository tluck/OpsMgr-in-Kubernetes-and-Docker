#!/bin/bash

source init.conf 

if [[ -e deploy.conf ]]
then
    source deploy.conf
else
    get_key.bash
    source deploy.conf
fi

out=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/clusters?pretty=true" )

printf "%s" "$out" | jq '.results[]'
