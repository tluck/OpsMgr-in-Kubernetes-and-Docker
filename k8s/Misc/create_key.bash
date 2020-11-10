#!/bin/bash

cat init.conf |sed -e '/publicApiKey/d' -e '/keyUser/d' > new
keyUser="$(         kubectl get secret opsmanager-admin-key -o json | jq .data.user |         sed -e's/"//g'| base64 --decode )"
publicApiKey="$( kubectl get secret opsmanager-admin-key -o json | jq .data.publicApiKey | sed -e's/"//g'| base64 --decode )"
echo keyUser="\"${keyrUser}\"" 
echo publicApiKey="\"${publicApiKey}\""
echo keyUser="\"${keyUser}\""  >> new
echo publicApiKey="\"${publicApiKey}\"" >> new
mv new init.conf

source ./init.conf

rm key.json > /dev/null 2>&1
curl --insecure --user "${keyUser}:${publicApiKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request POST "${opsMgrUrl}/api/public/v1.0/admin/apiKeys?pretty=true" \
  --data '{
    "desc" : "New API key for Global Testing",
    "roles" : [ "GLOBAL_OWNER" ]
  }' \
  -o key.json > /dev/null 2>&1

if [[ -e "key.json" ]]
then
    cat init.conf |sed -e '/privateKey/d' -e '/publicKey/d' > new
    echo  publicKey="$( cat key.json |jq .publicKey )"
    echo  privateKey="$( cat key.json |jq .privateKey )"
    echo  publicKey="$( cat key.json |jq .publicKey )" >> new
    echo  privateKey="$( cat key.json |jq .privateKey )" >> new
    mv new init.conf
else
    printf "%s\n" "Error did not create key"
    exit 1
fi
