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

tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
version=$( kubectl get mdb ${name} -o jsonpath='{.spec.version}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"refix"* || "${tls}" == *"ecret"* ]]
then
    eval serverpem=$( kubectl get secret mdb-${name}${mongos}-cert-pem -o json |jq ".data"| jq "keys[]" )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile /mongodb-automation/tls/ca/ca-pem --sslPEMKeyFile /mongodb-automation/tls/${serverpem}"
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile /mongodb-automation/tls/ca/ca-pem --tlsCertificateKeyFile /mongodb-automation/tls/${serverpem}"
        ssltls_enabled="&tls=true"
    fi
fi
# use mongo or mongosh (v6)
mongo=mongo
if [[ ${version%%.*} = 6 ]]
then
mongo=mongosh
fi

#eval cs=mongodb://${dbuser}:${dbpassword}@${name}-0:27017/?replicaSet=${name}
ics=$( kubectl get secret ${name}-${name}-${dbuserlc}-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
fcs=\'${ics}${ssltls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${ssltls_options}"
path="$( kubectl exec ${name}${mongos}-0  -- find /var/lib/ -name ${mongo} )"
mongosh=$( printf "%s" $path)
eval "kubectl exec ${name}${mongos}-0 -i -t -- ${mongosh} ${fcs} ${ssltls_options}"
