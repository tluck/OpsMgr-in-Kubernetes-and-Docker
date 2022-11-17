#!/bin/bash

source init.conf

while getopts 'n:rsh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    s) sharded="1" ;;
    r) sharded="1" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] [-s] [-r] -- Note: use -s or -r for a sharded cluster"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myreplicaset}
if [[ "${sharded}" == "1" ]]
then
    mongos="-s"
fi

export PATH=.:Misc:$PATH

fcs=$( get_connection_string.bash -n "${name}" "${mongos}" )
printf "\n%s\n\n" "Connect String: ${fcs}"
eval "mongosh ${fcs}"
