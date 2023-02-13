#!/bin/bash

source init.conf
test -f custom.conf && source custom.conf

while getopts 'i:h' opt
do
  case "$opt" in
    i) orgId="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -i orgId [-h]"
      exit 1
      ;;
  esac
done

if [[ $orgId == "" ]]
then
    printf "%s\n" "none"
    exit
fi

oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl2}/api/public/v1.0/orgs/$orgId?pretty=true" )

errorCode=$( printf "%s" "$oid" | jq .errorCode )
orgId=$( eval printf $oid)

if [[ "${errorCode}" == "null" ]]
then
#    conf=$( sed -e '/orgId=/d' custom.conf )
#    printf "%s\n" "${conf}" > custom.conf
    name=( $( printf "%s" "$oid" | jq ".name,.id" ))
    eval echo ${name[*]}
else
    printf "%s\n" "none"
    exit 0
fi
