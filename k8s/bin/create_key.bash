#!/bin/bash

source init.conf
test -e custom.conf && source custom.conf

adminUser="$(     kubectl get secret admin-user-credentials -o json | jq .data.Username |         sed -e's/"//g'| base64 --decode )"
publicApiKey="$(  kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.publicKey  | sed -e's/"//g'| base64 --decode )"
privateApiKey="$( kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.privateKey | sed -e's/"//g'| base64 --decode )"

    conf=$( sed -e '/adminUser/d' -e '/privateApiKey/d' -e '/publicApiKey/d'  custom.conf )
    printf "%s\n" "$conf" > custom.conf
    echo  publicApiKey="${publicApiKey}"   | tee custom.conf
    echo  privateApiKey="${privateApiKey}" | tee -a custom.conf

if [[ $publicKey == "" ]]
then
    file=/tmp/key.json
    rm "${file}" > /dev/null 2>&1
curl --insecure --user "${publicApiKey}:${privateApiKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrExtUrl2}/api/public/v1.0/admin/apiKeys?pretty=true" \
  --data '{
    "desc" : "New API key for Global Testing",
    "roles" : [ "GLOBAL_OWNER" ]
  }' \
  -o "${file}" > /dev/null 2>&1

if [[ -e "${file}" ]]
then
    echo  publicKey="$(  cat ${file} |jq .publicKey  )" | tee -a custom.conf
    echo  privateKey="$( cat ${file} |jq .privateKey )" | tee -a custom.conf
else
    printf "%s\n" "Error did not create key"
    exit 1
fi

else
    echo  publicKey="$publicKey"
    echo  privateKey="$privateKey"
fi
