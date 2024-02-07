#!/bin/bash

# script to find out if there is an existing non-deleted Organization and what is the id

source init.conf
test -f ${deployconf} && source ${deployconf}

while getopts 'p:rh' opt
do
  case "$opt" in
    p) projectName="$OPTARG";;
    r) reset='-r';;
    ?|h)
      echo "Usage: $(basename $0) -p projectName [-r] [-h]"
      echo "       -r will restore to previous policy"
      exit 1
      ;;
  esac
done

projectName=${projectName:-myproject1}
projectId=$(get_projectId.bash -p ${projectName})

printf "Updating policy for projectName: $projectName, id: $projectId\n"
set_policy.bash ${reset} -p ${projectId}

exit 0
