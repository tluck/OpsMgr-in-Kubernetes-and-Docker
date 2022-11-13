#!/bin/bash

initconf=$( sed -e '/myNodeIp/d' init.conf )
printf "%s\n" "${initconf}" > init.conf
myNodeIp="$( kubectl get node/docker-desktop -o json |jq .status.addresses[0].address)"
echo myNodeIp="${myNodeIp}" | tee -a init.conf

source init.conf
file="whitelist.json"

printf "%s\n" '{ "cidrBlock": "MYIP", "description": "my IP"}' | sed -e"s?MYIP?${myNodeIp}/1?g" > data.json
curl --user "${publicApiKey}:${privateApiKey}" --digest \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--request POST "${opsMgrUrl}/api/public/v1.0/admin/whitelist?pretty=true" \
--data @data.json \
-o "${file}" > /dev/null 2>&1
rm data.json

cat "${file}"
rm "${file}"
