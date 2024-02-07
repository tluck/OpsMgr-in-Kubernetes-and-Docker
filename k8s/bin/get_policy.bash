#!/bin/bash

source init.conf
test -f ${deployconf} && source ${deployconf}

while getopts 'p:h' opt
do
  case "$opt" in
    p) projectId="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -p projectId [-h]"
      exit 1
      ;;
  esac
done

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request GET "${opsMgrExtUrl1}/api/public/v1.0/groups/${projectId}/controlledFeature?pretty=true" )

errorCode=$( printf "%s" "$output" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    printf "%s\n" "$output" | jq
    exit 0
else
    printf "%s\n" "none"
    exit 1
fi
