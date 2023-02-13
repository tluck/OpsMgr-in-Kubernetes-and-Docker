#!/bin/bash

source init.conf
test -f custom.conf && source custom.conf

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

orgName="${orgName:-myOrg}"
if [[ $orgId != "" ]]
then 
    name=( $( bin/get_org.bash -i $orgId) )
fi
if [[ ${name[0]} == $orgName ]]
then
    exit
fi

ifile=tmpdata.json
echo '{ "name" : "NAME" }' | sed -e"s/NAME/${orgName}/" > ${ifile}

#rm ${ofile} > /dev/null 2>&1
oid=$( curl $curlOpts --silent --user "${publicKey}:${privateKey}" --digest \
 --header 'Accept: application/json' \
 --header 'Content-Type: application/json' \
 --request POST "${opsMgrExtUrl2}/api/public/v1.0/orgs?pretty=true" \
 --data @tmpdata.json ) 
errorCode=$( printf "%s" "$oid" | jq .errorCode )
rm ${ifile}
orgId=$( eval printf $oid)

if [[ "${errorCode}" == "null" ]]
then
    conf=$( sed -e '/orgName=/d' -e '/orgId=/d' custom.conf )
    printf "%s\n" "${conf}" > custom.conf
    printf "\n%s\n" "Successfully created Organization: $orgName"
    echo  orgName=\"${orgName}\"                   >> custom.conf
    echo  orgId="$( printf "%s" "$oid" | jq .id )" >> custom.conf
else
    printf "%s\n" "* * * Error - Organiztion creation failed"
    exit 1
fi
