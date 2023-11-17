#!/bin/bash

source init.conf
source custom.conf

while getopts 'i:o:p:u:h' opt
do
  case "$opt" in
    i|o) orgName="$OPTARG";;
    p) projectName="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName -p projectName [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

orgName=${orgName:-myOrg}
orgInfo=( $( get_org.bash -o ${orgName} ) )
orgId=${orgInfo[1]}
projectName=${projectName:-myProject}
#curlData=$( printf '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${projectName}/" -e"s/ORGID/${orgId}/" )
projectId=$( get_projectId.bash -p ${projectName} )

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request DELETE "${opsMgrExtUrl2}/api/public/v1.0/groups/{$projectId}" )
errorCode=$( printf "%s" "$output" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}_Id/d" -e "/${projectName}_agentApiKey/d" custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    exit 0
else
    detail=$( printf "%s" "$output" | jq .detail )
    printf "%s\n" " * * * Error did not delete projectName.\n $detail \n"
    exit 1
fi
