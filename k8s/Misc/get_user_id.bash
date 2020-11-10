#!/bin/bash 

source init.conf

user=$1

curl --user "${publicKey}:${privateKey}" --digest \
  --header "Accept: application/json" \
  --header "Content-Type: application/json" \
  --request GET "${opsMgrUrl}/api/public/v1.0/users/byName/${keyUser}?pretty=true" \
  -o user.json > /dev/null 2>&1

cat init.conf |sed -e '/userId/d' > new
echo  userId="$( cat user.json | jq .id )"
echo  userId="$( cat user.json | jq .id )" >> new
mv new init.conf

exit

