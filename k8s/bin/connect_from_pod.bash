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
if [[ ${version%%.*} > 4 ]]
then
mongo=mongosh
fi

ics=$( get_connection_string.bash -n "${name}" -i )
fcs=${ics#*:}
printf "\n%s %s\n\n" "Connect String: ${fcs} "

# update old mongosh
kubectl exec ${name}${mongos}-0 -i -t -- bash -c "curl -s https://downloads.mongodb.com/compass/mongosh-1.6.2-linux-x64.tgz -o /var/lib/mongodb-mms-automation/mongosh-1.6.2-linux-x64.tgz; cd /var/lib/mongodb-mms-automation/ ; tar -zxvf mongosh-1.6.2-linux-x64.tgz; rm mongosh-1.6.2-linux-x64.tgz"

path="$( kubectl exec ${name}${mongos}-0  -- find /var/lib/ -name ${mongo} |grep "1.6.2")"
mongosh=$( printf "%s" $path)
eval "kubectl exec ${name}${mongos}-0 -i -t -- ${mongosh} ${fcs} "
