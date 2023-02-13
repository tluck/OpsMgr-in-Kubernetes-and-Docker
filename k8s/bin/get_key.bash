#!/bin/bash

source init.conf
test -e custom.conf && source custom.conf

adminUser="$(     kubectl get secret admin-user-credentials -o json | jq .data.Username |         sed -e's/"//g'| base64 --decode )"
publicApiKey="$(  kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.publicKey  | sed -e's/"//g'| base64 --decode )"
privateApiKey="$( kubectl get secret ${namespace}-opsmanager-admin-key -o json | jq .data.privateKey | sed -e's/"//g'| base64 --decode )"

    conf=$( sed -e '/privateKey/d' -e '/publicKey/d' custom.conf )
    printf "%s\n" "$conf" > custom.conf
    echo  publicKey="${publicApiKey}"   >> custom.conf
    echo  privateKey="${privateApiKey}" >> custom.conf
