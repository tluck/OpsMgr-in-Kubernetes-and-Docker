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
    mongos="-mongos"
fi

eval serverpem=$( kubectl get secret mdb-${name}${mongos}-cert-pem -o json |jq ".data"| jq "keys[]" )
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.authentication}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" ==  *"\"enabled\":true"* ]]
then
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
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

#eval cs=mongodb://${dbadmin}:${dbpassword}@${name}-0:27017/?replicaSet=${name}
ics=$( kubectl get secret ${name}-dbadmin-${name}-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
fcs=\'${ics}${ssltls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${ssltls_options}"
path="$( kubectl exec ${name}${mongos}-0  -- find /var/lib/ -name ${mongo} )"
mongosh=$( printf "%s" $path)
eval "kubectl exec ${name}${mongos}-0 -i -t -- ${mongosh} ${fcs} ${ssltls_options}"
