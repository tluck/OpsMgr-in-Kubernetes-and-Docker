#!/bin/bash

source init.conf

while getopts 'n:mlh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    m) multiCluster="-m" ;;
    l) ldap="-l"      ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

ns="-n $namespace"
mdbKind="MongoDB"
if [[ ${multiCluster} == "-m" ]]
then
    clusterDomain="${multiClusterDomain}"
    mdbKind="MongoDBMultiCluster"
    context="--context=$MDB_CLUSTER_0_CONTEXT"
    ns="-n $mcNamespace"
    member="-0"
fi

name=${name:-myproject1-myreplicaset}
type=$( kubectl $ns get ${mdbKind}/${name} -o jsonpath='{.spec.type}' )
#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    sharded=1
    mongos="-mongos"
fi

version=$( kubectl $ns get ${mdbKind} ${name} -o jsonpath='{.spec.version}' )
# use mongo or mongosh (v6)
mongo=mongo
if [[ ${version%%.*} > 4 ]]
then
mongo=mongosh
fi

ics=$( get_connection_string.bash -n "${name}" -i $ldap $multiCluster )
fcs=${ics#*:}
printf "\n%s %s\n\n" "Connect String: ${fcs} "

path="$( kubectl $context $ns exec ${name}${mongos}${member}-0 -c "mongodb-enterprise-database" -- find /var/lib/mongodb-mms-automation/ -name ${mongo} |grep "${mongoshVersion}")"
if [[ x${path}x == xx ]]
then
# update old mongosh
    printf "Updating mongosh\n"
    kubectl $context $ns exec ${name}${mongos}${member}-0 -i -t -c "mongodb-enterprise-database" -- bash -c "curl -s https://downloads.mongodb.com/compass/mongosh-${mongoshVersion}-linux-x64.tgz -o /var/lib/mongodb-mms-automation/mongosh-${mongoshVersion}-linux-x64.tgz; cd /var/lib/mongodb-mms-automation/ ; tar -zxvf mongosh-${mongoshVersion}-linux-x64.tgz; rm mongosh-${mongoshVersion}-linux-x64.tgz"
    path="$( kubectl $context $ns exec ${name}${mongos}${member}-0 -c "mongodb-enterprise-database" -- find /var/lib/mongodb-mms-automation/ -name ${mongo} |grep "${mongoshVersion}")"
fi
mongosh=$( printf "%s" $path)
eval "kubectl $context $ns exec ${name}${mongos}${member}-0 -i -t -c "mongodb-enterprise-database" -- ${mongosh} ${fcs} "
