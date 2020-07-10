#!/bin/bash

cat init.conf |sed -e '/myNodeIp/d'  > new
myNodeIp="$( kubectl get node/docker-desktop -o json |jq .status.addresses[0].address)"
echo myNodeIp="${myNodeIp}"
echo myNodeIp="${myNodeIp}" >> new
mv new init.conf

. init.conf

printf "%s\n" '{ "cidrBlock": "MYIP", "description": "my IP"}' | sed -e"s?MYIP?${myNodeIp}/1?g" > data.json
curl --user "${user}:${publicApiKey}" --digest \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--request POST "http://opsmgr:32080/api/public/v1.0/admin/whitelist?pretty=true" \
--data @data.json \
-o whitelist.json > /dev/null 2>&1

cat whitelist.json
