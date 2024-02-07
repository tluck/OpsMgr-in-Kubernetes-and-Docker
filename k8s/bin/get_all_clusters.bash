#!/bin/bash

source init.conf 

if [[ -e ${deployconf} ]]
then
    source ${deployconf}
else
    get_key.bash
    source ${deployconf}
fi

out=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl1}/api/public/v1.0/clusters?pretty=true" )

printf "%s" "$out" | jq '.results[]'
