#!/bin/bash

# script to find out if there is an existing non-deleted Organization and what is the id

source init.conf
test -f custom.conf && source custom.conf

while getopts 'p:rh' opt
do
  case "$opt" in
    p) projectId="$OPTARG";;
    r) reset=true;;
    ?|h)
      echo "Usage: $(basename $0) -p projectId [-h]"
      exit 1
      ;;
  esac
done

output=$( get_policy.bash -p $projectId )
errorCode=$( printf "%s" "$output" | jq .errorCode )

printf "%s\n" "Current policy"
printf "%s" "$output" | jq '.policies' 
if [[ ! -e ${projectId}_policy.json ]]
then
  printf "%s" "$output" |jq '.policies'  > ${projectId}_policy.json
fi

if [[ "${errorCode}" == "null" ]]
then
  if [[ ${reset} == true ]]
  then
    policy='{"policies":'$( cat ${projectId}_policy.json )'}'
  else
    policy='{"policies": []}'
  fi
  jsonData=$( printf "%s" "$output" |jq 'del(.policies,.updated,.created)'| jq '. +='"${policy}"' ' )
  curlData=' '"$jsonData"' '

  output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --request PUT "${opsMgrExtUrl2}/api/public/v1.0/groups/${projectId}/controlledFeature?pretty=true" \
  --data "${curlData}" )
fi

errorCode=$( printf "%s" "$output" | jq '.errorCode' )
if [[ "${errorCode}" == "null" ]]
then
    printf "\n%s\n" "New policy"
    printf "%s" "$output" | jq '.policies' 
    [[ ${reset} == true ]] && rm ${projectId}_policy.json
    exit 0
else
    printf "%s\n" "none"
    exit 1
fi
