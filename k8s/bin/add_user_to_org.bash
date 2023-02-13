#!/bin/bash

source init.conf
source custom.conf

orgname=${1:-myOrg}

echo '{
        "roles": [
        {
          "orgId" : "ORGID",
          "roleName" : "ORG_OWNER"
        }]
      }' | sed -e"s/ORGID/${orgId}/" > tmpdata.json

curl $curlOpts --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
     --request PATCH "${opsMgrExtUrl2}/api/public/v1.0/users/${userId}" \
     --data @tmpdata.json > /dev/null 2>&1

errorCode=$?

if [[ "$errorCode" == "0" ]]
then
    printf "%s\n" "Successfully added user $user with userId $userId to $orgname"
fi

rm tmpdata.json
exit $errorCode

