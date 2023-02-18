#!/bin/bash 

# creates custom.conf with the out from below
source init.conf

while getopts 'i:o:u:h' opt
do
  case "$opt" in
    i|o) orgName="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName -u user [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

orgName="${orgName:-myOrg}"

#bin/create_key.bash
bin/get_key.bash
if [[ $? != 0 ]]
then
    exit 1
fi
# create the newOrg with the key
bin/create_org.bash -o "${orgName}"
if [[ $? != 0 ]]
then
    rm custom.conf
    exit 1
fi
source custom.conf
# user can be supplied or is in init.conf
# add user to the org (orgId is in custom.conf)
bin/add_user_to_org.bash -u "${user}" -i "${orgId}"
#cat custom.conf
