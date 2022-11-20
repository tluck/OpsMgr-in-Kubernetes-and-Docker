#!/bin/bash

source ./init.conf

orgname="${1:-DemoOrg}"

ifile=data.json

echo '{ "name" : "NAME" }' | sed -e"s/ORGID/${orgId}/" -e"s/NAME/${orgname}/" > ${ifile}

#rm ${ofile} > /dev/null 2>&1
oid=$( curl --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request POST "${opsMgrUrl}/api/public/v1.0/orgs?pretty=true" \
 --data @data.json ) 
#\ # -o ${ofile} > /dev/null 2>&1
errorCode=$( printf "%s" "$oid" | jq .errorCode )
rm ${ifile}
orgId=$( eval printf $oid)

if [[ "${errorCode}" == "null" ]]
then
    initconf=$( sed -e '/orgId=/d' init.conf )
    printf "%s\n" "${initconf}" > init.conf
    printf "\n%s\n" "Successfully created Organization: $orgName"
    echo  orgId="$( printf "%s" "$oid" | jq .id )" | tee -a init.conf
else
    printf "%s\n" "Error did not create org"
    exit 1
fi
