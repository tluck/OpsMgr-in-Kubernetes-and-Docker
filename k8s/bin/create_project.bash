#!/bin/bash

source init.conf
source ${deployconf}

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
     --request POST "${opsMgrExtUrl1}/api/public/v1.0/groups?pretty=true" \
     --data "${curlData}" )
errorCode=$( printf "%s" "$output" | jq .errorCode )

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${projectName}_Id/d" -e "/${projectName}_agentApiKey/d" ${deployconf} )
    printf "%s\n" "${conf}" > ${deployconf}
    printf "%s\n" "Successfully created Project: $projectName in OrgId: ${orgId}"
#    echo  projectName=\"${projectName}\"                                        >> ${deployconf}
    echo  ${projectName}_projectId="$(   printf "%s" "$output" | jq .id )"          >> ${deployconf}
    echo  ${projectName}_agentApiKey="$( printf "%s" "$output" | jq .agentApiKey )" >> ${deployconf}
else
    detail=$( printf "%s" "$output" | jq .detail )
    printf "%s\n" "* * * Error - did not create projectName.\n $detail \n"
    exit 1
fi
