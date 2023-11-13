#!/bin/bash

source init.conf

adminUser="$(     kubectl get secret admin-user-credentials -o json | jq .data.Username |         sed -e's/"//g'| base64 --decode )"
kpublicApiKey="$(  kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.publicKey  | sed -e's/"//g'| base64 --decode )"
kprivateApiKey="$( kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.privateKey | sed -e's/"//g'| base64 --decode )"

test -e custom.conf && source custom.conf

if [[ $publicApiKey == "" ]]
then
output=$( curl $curlOpts --silent --user "${kpublicApiKey}:${kprivateApiKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrExtUrl2}/api/public/v1.0/admin/apiKeys?pretty=true" \
  --data '{
    "desc" : "New API key for Global Testing",
    "roles" : [ "GLOBAL_OWNER" ]
    }' )

    if [[ "${output}" != "" ]]
    then
        printf  "Created new keys\n"
        printf  "publicApiKey=$(  printf "${output}" |jq .publicKey  )\n" | tee -a custom.conf
        printf  "privateApiKey=$( printf "${output}" |jq .privateKey )\n" | tee -a custom.conf
    else
        printf "%s\n" " * * * Error did not create any keys"
        exit 1
    fi

else
    printf  "Existing keys\n"
    printf  "\tpublicKey=\"${publicKey}\"\n" 
    printf  "\tprivateKey=\"${privateKey}\"\n" 
    printf  "\tpublicApiKey=\"${publicApiKey}\"\n" 
    printf  "\tprivateApiKey=\"${privateApiKey}\"\n" 
fi
