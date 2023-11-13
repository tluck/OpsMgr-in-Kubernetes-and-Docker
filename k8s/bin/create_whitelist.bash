#!/bin/bash

conf=$( sed -e '/myNodeIp/d' custom.conf )
printf "%s\n" "${conf}" > custom.conf
eval nodes=( $( kubectl get node -o json |jq ".items[].status.addresses[0].address" ) )
myNodeIp=${nodes[0]}
printf "myNodeIp=${myNodeIp}" | tee -a custom.conf

source init.conf
source custom.conf

curlData=$( printf '{ "cidrBlock": "MYIP", "description": "my IP"}' | sed -e"s?MYIP?${myNodeIp}/1?g" )
output=$( curl $curlOpts --silent --user "${publicApiKey}:${privateApiKey}" --digest \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--request POST "${opsMgrExtUrl2}/api/public/v1.0/admin/whitelist?pretty=true" \
--data "${curlData}" )

printf "${output}"
