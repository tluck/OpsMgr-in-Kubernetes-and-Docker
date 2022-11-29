#!/bin/bash

source init.conf

while getopts 'n:h' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myreplicaset}
dbuserlc=$( printf "$dbuser" | tr '[:upper:]' '[:lower:]' )
type=$( kubectl get mdb/${name} -o jsonpath='{.spec.type}' )
#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    sharded=1
    mongos="-mongos"
fi

version=$( kubectl get mdb ${name} -o jsonpath='{.spec.version}' )
# use mongo or mongosh (v6)
mongo=mongo
if [[ ${version%%.*} = 6 ]]
then
mongo=mongosh
fi

ics=$( get_connection_string.bash -n "${name}" -i )
fcs=${ics#*:}
printf "\n%s %s\n\n" "Connect String: ${fcs} "
path="$( kubectl exec ${name}${mongos}-0  -- find /var/lib/ -name ${mongo} )"
mongosh=$( printf "%s" $path)
eval "kubectl exec ${name}${mongos}-0 -i -t -- ${mongosh} ${fcs} "
