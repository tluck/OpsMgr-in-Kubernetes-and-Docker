#!/bin/bash 

source init.conf

username="${1:-$user}"
file=/tmp/user.json

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrUrl}/api/public/v1.0/users/byName/${username}?pretty=true" \
  -o ${file} > /dev/null 2>&1

errorCode=$?

initconf=$( sed -e '/userId/d' init.conf ) 
printf "%s\n" "${initconf}" > init.conf
printf "\n%s\n" "User $username is:"
echo  userId="$( cat ${file} | jq .id )" | tee -a init.conf

exit $errorCode

