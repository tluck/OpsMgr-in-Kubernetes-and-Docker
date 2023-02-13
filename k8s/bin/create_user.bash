#!/bin/bash

source custom.conf
source init.conf

echo '{ "username":     "sharath.rao@mongodb.com",
        "emailAddress": "sharath.rao@mongodb.com",
        "firstName":    "Sharath",
        "lastName":     "Rao",
        "password":     "Mongodb1$",
        "roles": [ { "orgId": "ORGID", "roleName": "ORG_OWNER" } ]
      }' | sed -e"s/ORGID/${orgId}/" > data.json

curl $curlOpts -s --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrExtUrl2}/api/public/v1.0/users" \
  --data @data.json \
  -o newuser.json > /dev/null 2>&1

cat newuser.json
rm newuser.json data.json

exit
