#!/bin/bash 

source init.conf
source custom.conf

username="${1:-$user}"
file=/tmp/user.json

curl $curlOpts --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrExtUrl2}/api/public/v1.0/users/byName/${username}?pretty=true" \
  -o ${file} > /dev/null 2>&1

errorCode=$?

conf=$( sed -e '/userId/d' custom.conf ) 
printf "%s\n" "${conf}" > custom.conf
#printf "\n%s\n" "User $username is:"
echo  userId="$( cat ${file} | jq .id )" >> custom.conf

exit $errorCode

