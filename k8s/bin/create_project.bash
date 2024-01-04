#!/bin/bash

source init.conf
source deploy.conf

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

orgName=${orgName:-myDeployment}
orgInfo=( $( get_org.bash -o ${orgName} ) )
orgId=${orgInfo[1]}
projectName=${projectName:-myProject}
curlData=$( printf '{ "name" : "PROJECT", "orgId" : "ORGID" }' | sed -e"s/PROJECT/${projectName}/" -e"s/ORGID/${orgId}/" )

output=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
     --header "Content-Type: application/json" \
     --request POST "${opsMgrExtUrl2}/api/public/v1.0/groups?pretty=true" \
     --data "${curlData}" )
errorCode=$( printf "%s" "$output" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}_Id/d" -e "/${projectName}_agentApiKey/d" deploy.conf )
    printf "%s\n" "${conf}" > deploy.conf
    printf "%s\n" "Successfully created Project: $projectName in OrgId: ${orgId}"
#    echo  projectName=\"${projectName}\"                                        >> deploy.conf
    echo  ${projectName}_projectId="$(   printf "%s" "$output" | jq .id )"          >> deploy.conf
    echo  ${projectName}_agentApiKey="$( printf "%s" "$output" | jq .agentApiKey )" >> deploy.conf
else
    detail=$( printf "%s" "$output" | jq .detail )
    printf "%s\n" "* * * Error - did not create projectName.\n $detail \n"
    exit 1
fi
