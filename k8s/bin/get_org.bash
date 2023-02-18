#!/bin/bash

source init.conf
test -f custom.conf && source custom.conf

while getopts 'i:o:h' opt
do
  case "$opt" in
    o) orgName="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done

orgName=${orgName:-myOrg}

oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/orgs/?pretty=true" )

errorCode=$( printf "%s" "$oid" | jq .errorCode )

out=( $( printf "%s" "$oid" | jq --arg orgName "$orgName" '.results[]| select( .name == $orgName ) | .name,.id' ))
eval out=( $( printf '%s ' "${out[*]}" ) )

if [[ "${errorCode}" == "null" ]]
then
    printf  "${out[*]}"
else
    printf "%s\n" "none"
    exit 0
fi
