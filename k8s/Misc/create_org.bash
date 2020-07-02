#!/bin/bash

. init.conf

curl --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request POST "http://opsmgr:32080/api/public/v1.0/orgs?pretty=true" \
 --data '{ "name" : "Demo" }' \
 -o org.json > /dev/null 2>&1

cat init.conf |sed -e '/orgId/d' > new
echo  orgId="$( cat org.json | jq .id )"
echo  orgId="$( cat org.json | jq .id )" >> new
mv new init.conf
