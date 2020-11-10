#!/bin/bash

source ./init.conf

orgname=$1

echo '{
        "roles": [
        {
          "orgId" : "ORGID",
          "roleName" : "ORG_OWNER"
        }]
      }' | sed -e"s/ORGID/${orgId}/" > data.json

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
     --request PATCH "${opsMgrUrl}/api/public/v1.0/users/${userId}" \
     --data @data.json > /dev/null 2>&1

exit

