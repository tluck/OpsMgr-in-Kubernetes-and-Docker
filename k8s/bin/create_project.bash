#!/bin/bash

source init.conf
source custom.conf

while getopts 'i:o:p:u:h' opt
do
  case "$opt" in
    i|o) orgId="$OPTARG";;
    p) projectName="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#orgId=${}
projectName=${projectName:-myProject}

echo '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${projectName}/" -e"s/ORGID/${orgId}/" > data.json
pid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups?pretty=true" \
     --data @data.json )
errorCode=$( printf "%s" "$pid" | jq .errorCode )
rm data.json

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}_Id/d" -e "/${projectName}_agentApiKey/d" custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    printf "%s\n" "Successfully created Project: $projectName in OrgId: ${orgId}"
#    echo  projectName=\"${projectName}\"                                        >> custom.conf
    echo  ${projectName}_Id="$(          printf "%s" "$pid" | jq .id )"          >> custom.conf
    echo  ${projectName}_agentApiKey="$( printf "%s" "$pid" | jq .agentApiKey )" >> custom.conf
else
    detail=$( printf "%s" "$pid" | jq .detail )
    printf "%s\n" "Error did not create projectName: $detail"
    exit 1
fi
