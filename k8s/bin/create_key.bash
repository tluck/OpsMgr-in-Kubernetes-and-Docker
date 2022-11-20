#!/bin/bash

adminUser="$(     kubectl get secret admin-user-credentials -o json | jq .data.Username |         sed -e's/"//g'| base64 --decode )"
publicApiKey="$(  kubectl get secret mongodb-opsmanager-admin-key -o json | jq .data.publicKey  | sed -e's/"//g'| base64 --decode )"
privateApiKey="$( kubectl get secret mongodb-opsmanager-admin-key -o json | jq .data.privateKey | sed -e's/"//g'| base64 --decode )"

initconf=$( sed -e '/adminUser/d' -e '/private.*Key/d' -e '/public.*Key/d'  init.conf )
printf "%s\n" "$initconf" > init.conf

#echo  adminUser="${adminUser}" | tee -a init.conf
echo  publicApiKey="${publicApiKey}"   | tee -a init.conf
echo  privateApiKey="${privateApiKey}" | tee -a init.conf

source init.conf
file=/tmp/key.json
rm "${file}" > /dev/null 2>&1
curl --insecure --user "${publicApiKey}:${privateApiKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrUrl}/api/public/v1.0/admin/apiKeys?pretty=true" \
  --data '{
    "desc" : "New API key for Global Testing",
    "roles" : [ "GLOBAL_OWNER" ]
  }' \
  -o "${file}" > /dev/null 2>&1

if [[ -e "${file}" ]]
then
    echo  publicKey="$(  cat ${file} |jq .publicKey  )" | tee -a init.conf
    echo  privateKey="$( cat ${file} |jq .privateKey )" | tee -a init.conf
else
    printf "%s\n" "Error did not create key"
    exit 1
fi
