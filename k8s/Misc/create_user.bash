#!/bin/bash

source ./init.conf

echo '{ "username":     "sharath.rao@mongodb.com",
        "emailAddress": "sharath.rao@mongodb.com",
        "firstName":    "Sharath",
        "lastName":     "Rao",
        "password":     "Mongodb1$",
        "roles": [ { "orgId": "ORGID", "roleName": "ORG_OWNER" } ]
      }' | sed -e"s/ORGID/${orgId}/" > data.json

curl -s --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrUrl}/api/public/v1.0/users" \
  --data @data.json \
  -o newuser.json > /dev/null 2>&1

exit

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "http://opsmgr:32080/api/public/v1.0/users" \
  --data \"
    {
      "username": "john.doe@mongodb.com",
      "emailAddress": "john.doe@mongodb.com",
      "firstName": "John",
      "lastName": "Doe",
      "password": "M0ng0D8!:)",
      "roles": [{
        "groupId": "5ee6876f23ac1a43e1df0b50",
        "roleName": "GROUP_BACKUP_ADMIN"
      },{
        "orgId" : "${ORGID}",
        "roleName" : "ORG_MEMBER"
      }]
    }\"


