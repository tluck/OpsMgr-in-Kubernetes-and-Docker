#!/bin/bash

source init.conf
source custom.conf

while getopts 'i:o:u:h' opt
do
  case "$opt" in
    i|o) orgId="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -i orgId -u userId [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrExtUrl2}/api/public/v1.0/users/byName/${user}?pretty=true" )

errorCode=$?

#printf "${output}" 
eval userId=$( printf "${output}" | jq .id ) 

curlData=$( printf '{
        "roles": [
        {
          "orgId" : "ORGID",
          "roleName" : "ORG_OWNER"
        }]
      }' | sed -e"s/ORGID/${orgId}/" )

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
     --request PATCH "${opsMgrExtUrl2}/api/public/v1.0/users/${userId}" \
     --data "${curlData}" )

errorCode=$?

if [[ "$errorCode" == "0" ]]
then
    printf "%s\n" "Successfully added User: $user with userId: $userId to orgId: $orgId"
fi

exit $errorCode
