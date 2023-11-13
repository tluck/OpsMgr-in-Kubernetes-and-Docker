#!/bin/bash

source init.conf
test -e custom.conf && source custom.conf

adminUser="$(     kubectl get secret admin-user-credentials -o json | jq .data.Username |         sed -e's/"//g'| base64 --decode )"
publicApiKey="$(  kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.publicKey  | sed -e's/"//g'| base64 --decode )"
privateApiKey="$( kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.privateKey | sed -e's/"//g'| base64 --decode )"

if [[ "${publicApiKey}" == ""  ]]
then
    printf "* * * Error - cannot get the API key"
    exit 1
fi

if [[ $publicApiKey != $publicKey ]]
then
    if [[ -e custom.conf ]]
    then
        conf=$( sed -e '/adminUser/d' -e '/privateKey/d' -e '/publicKey/d'  custom.conf )
        printf "%s\n" "$conf" > custom.conf
    fi
    printf "publicKey=\"${publicApiKey}\"\n"    | tee -a custom.conf
    printf "privateKey=\"${privateApiKey}\"\n"  | tee -a custom.conf
else
    printf "publicKey=\"${publicApiKey}\"\n" 
    printf "privateKey=\"${privateApiKey}\"\n" 
fi

exit 0
