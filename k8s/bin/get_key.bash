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

if [[ -e custom.conf ]]
then
    if [[ $publicApiKey != $publicKey ]]
    then
        rm custom.conf
        echo  publicKey="${publicApiKey}"   > custom.conf
        echo  privateKey="${privateApiKey}" >> custom.conf
    #else
    #    conf=$( sed -e '/privateKey/d' -e '/publicKey/d' custom.conf )
    #    printf "%s\n" "$conf" > custom.conf
    fi
else
    echo  publicKey="${publicApiKey}"   > custom.conf
    echo  privateKey="${privateApiKey}" >> custom.conf
fi

exit 0
