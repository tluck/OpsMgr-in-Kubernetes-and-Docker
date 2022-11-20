#!/bin/bash

source ./init.conf

orgname=${1:-DemoOrg}

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

errorCode=$?

if [[ "$errorCode" == "0" ]]
then
    printf "\n%s\n" "Successfully added userId $userId to $orgname"
fi

rm data.json
exit $errorCode

