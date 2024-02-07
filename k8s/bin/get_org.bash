#!/bin/bash

# script to find out if there is an existing non-deleted Organization and what is the id

source init.conf
test -f ${deployconf} && source ${deployconf}

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

orgName=${orgName:-myDeployment}

oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl1}/api/public/v1.0/orgs/?pretty=true" )

errorCode=$( printf "%s" "$oid" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    orgName=( $( printf "%s" "$oid" | jq --arg orgName "$orgName" '.results[]| select( (.name == $orgName) and (.isDeleted == false) ) | .name,.id' ))
    eval out=( ${orgName[0]} ${orgName[1]} )
    [[ "x${out[0]}" == "x" ]] && out=( none none )
    printf "%s\n" "${out[*]}"
else
    printf "%s\n" "none none"
fi
exit 0
