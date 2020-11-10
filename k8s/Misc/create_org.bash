#!/bin/bash

source ./init.conf

orgname=$1

echo '{ "name" : "NAME" }' | sed -e"s/ORGID/${orgId}/" -e"s/NAME/${orgname}/" > data.json

rm org.json > /dev/null 2>&1
curl --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request POST "${opsMgrUrl}/api/public/v1.0/orgs?pretty=true" \
 --data @data.json \
 -o org.json > /dev/null 2>&1

if [[ -e "org.json" ]]
then
    cat init.conf |sed -e '/orgId/d' > new
    echo  orgId="$( cat org.json | jq .id )"
    echo  orgId="$( cat org.json | jq .id )" >> new
    mv new init.conf
else
    printf "%s\n" "Error did not create org"
    exit 1
fi
