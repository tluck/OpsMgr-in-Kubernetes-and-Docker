#!/bin/bash

source init.conf

while getopts 'n:mlh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    m) multiCluster="-m" ;;
    l) ldap="-l"      ;;
    ?|h)
      printf "%s\n" "Usage: $(basename $0) [-n clusterName] [-l] "
      printf "%s\n" "       use -n clusterName"
      printf "%s\n" "       use -m for a multiCluster MDB"
      printf "%s\n" "       use -l for LDAP connection string versus SCRAM"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

mdbKind="MongoDB"
if [[ ${multiCluster} == "-m" ]]
then
    clusterDomain="${multiClusterDomain}"
    mdbKind="MongoDBMultiCluster"
fi

name=${name:-myproject1-myreplicaset}
#export PATH=.:bin:$PATH

cs=$( get_connection_string.bash -n "${name}" $ldap $multiCluster )
fcs=${cs#*: }
printf "\n%s\n\n" "Connection String: ${fcs}"
eval "mongosh ${fcs}"
