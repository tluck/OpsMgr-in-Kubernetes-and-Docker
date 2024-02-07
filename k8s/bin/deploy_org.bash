#!/bin/bash 

# creates ${deployconf} with the out from below
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

orgName="${orgName:-myDeployment}"

#create_key.bash
get_key.bash
if [[ $? != 0 ]]
then
    exit 1
fi
# create the newOrg with the key
create_org.bash -o "${orgName}"
if [[ $? != 0 ]]
then
    #rm ${deployconf}
    exit 1
fi
source ${deployconf}
# user can be supplied or is in init.conf
# add user to the org (orgId is in ${deployconf})
orgId="${orgName}_orgId"
orgId="${!orgId}"
add_user_to_org.bash -u "${user}" -i "${orgId}"
#cat ${deployconf}
