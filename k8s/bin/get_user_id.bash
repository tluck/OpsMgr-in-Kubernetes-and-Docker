#!/bin/bash 

source init.conf
source custom.conf

while getopts 'u:h' opt
do
  case "$opt" in
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName -u user [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

file=/tmp/$$user.json

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrExtUrl2}/api/public/v1.0/users/byName/${user}?pretty=true" )

errorCode=$?

conf=$( sed -e '/userId/d' custom.conf ) 
printf "%s\n" "${conf}" > custom.conf
printf  "userId=$( printf "${output}" | jq .id )" >> custom.conf

exit $errorCode

