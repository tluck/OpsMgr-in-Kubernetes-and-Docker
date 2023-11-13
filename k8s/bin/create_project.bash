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
curlData=$( printf '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${projectName}/" -e"s/ORGID/${orgId}/" )

pid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups?pretty=true" \
     --data "${curlData}" )
errorCode=$( printf "%s" "$pid" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}_Id/d" -e "/${projectName}_agentApiKey/d" custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    printf "%s\n" "Successfully created Project: $projectName in OrgId: ${orgId}"
#    echo  projectName=\"${projectName}\"                                        >> custom.conf
    echo  ${projectName}_projectId="$(   printf "%s" "$pid" | jq .id )"          >> custom.conf
    echo  ${projectName}_agentApiKey="$( printf "%s" "$pid" | jq .agentApiKey )" >> custom.conf
else
    detail=$( printf "%s" "$pid" | jq .detail )
    printf "%s\n" "Error did not create projectName: $detail"
    exit 1
fi
