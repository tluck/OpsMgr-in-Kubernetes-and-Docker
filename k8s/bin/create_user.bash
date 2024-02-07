#!/bin/bash

source init.conf
source ${deployconf}

orgName=${orgName:-myDeployment}
orgInfo=( $( get_org.bash -o ${orgName} ) )
orgId=${orgInfo[1]}

curlData=$( printf '{ 
        "username":     "new.user@mongodb.com",
        "emailAddress": "new.user@mongodb.com",
        "firstName":    "New",
        "lastName":     "User",
        "password":     "Mongodb1$",
        "roles": [ { "orgId": "ORGID", "roleName": "ORG_OWNER" } ]
      }' | sed -e"s/ORGID/${orgId}/" )

output=$( curl $curlOpts -s --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrExtUrl1}/api/public/v1.0/users" \
  --data "${curlData}" )

printf "New User\n" 
printf "$output" | jq
exit
