#!/bin/bash

# script to find out if there is an existing non-deleted Organization and what is the id

source init.conf
test -f custom.conf && source custom.conf

while getopts 'p:rh' opt
do
  case "$opt" in
    p) projectName="$OPTARG";;
    r) reset='-r';;
    ?|h)
      echo "Usage: $(basename $0) -p projectId [-r] [-h]"
      exit 1
      ;;
  esac
done

projectId=$(get_project.bash -p ${projectName})

printf "Updating policy for projectName: $projectName, id: $projectId\n"
set_policy.bash ${reset} -p ${projectId}

exit 0
