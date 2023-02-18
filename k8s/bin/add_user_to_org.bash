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

file=/tmp/$$user.json
curl $curlOpts --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrExtUrl2}/api/public/v1.0/users/byName/${user}?pretty=true" \
  -o ${file} > /dev/null 2>&1

errorCode=$?

eval userId="$( cat ${file} | jq .id )" 

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
    printf "%s\n" "Successfully added User: $user with userId: $userId to orgId: $orgId"
fi

rm tmpdata.json
exit $errorCode

