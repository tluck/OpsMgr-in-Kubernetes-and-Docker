#!/bin/bash

source init.conf
test -f ${deployconf} && source ${deployconf}

while getopts 'o:h' opt
do
  case "$opt" in
    o) orgName="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# check to see if the org (still) exists
orgName="${orgName:-myDeployment}"
# test to see if the org already exits if so get the orgId
name=( $( get_org.bash -o ${orgName} ) )

if [[ ${name[0]} == $orgName ]]
then
    orgId=${name[1]}
    orgExists=1
    errorCode="null"
else

curlData=$( printf '{ "name" : "NAME" }' | sed -e"s/NAME/${orgName}/" )

oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request POST "${opsMgrExtUrl1}/api/public/v1.0/orgs?pretty=true" \
 --data "${curlData}" ) 

errorCode=$( printf "%s" "$oid" | jq .errorCode )
orgId="$( printf "%s" "$oid" | jq .id )" 
eval orgId=$orgId
fi

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e "/${orgName//-/_}_orgId=/d" ${deployconf} )
    printf "%s\n" "${conf}" > ${deployconf}
    if [[ ${orgExists} == 1 ]]
    then
    printf "\n%s\n" "Using the existing Organization: ${orgName} with orgID: ${orgId}" 
    else
    printf "\n%s\n" "Created a new Organization: ${orgName} with orgId: ${orgId}"
    fi
    printf  "${orgName//-/_}_orgId=\"${orgId}\"\n"     >> ${deployconf}
else
    printf "%s\n" "* * * Error - Organiztion creation failed"
    exit 1
fi
