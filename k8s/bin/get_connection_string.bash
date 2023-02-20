#!/bin/bash

source init.conf
PATH=.:bin:$PATH

while getopts 'n:ih' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    i) internal=1     ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myproject1-myreplicaset}
internal=${internal-0}

type=$( kubectl get mdb/${name} -o jsonpath='{.spec.type}' )
#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    sharded=1
    mongos="-mongos"
    serviceType=$( kubectl get svc/${name}-svc-external -o jsonpath='{.spec.type}' 2>/dev/null )
else
    serviceType=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.type}' 2>/dev/null )
fi

#cs="mongodb://${dbuser}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin"
ics=$( kubectl get secret ${name}-${name}-admin-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
ecs="${ics}"
if [[ ${serviceType} != "" ]]
then
hn=( $( bin/get_hns.bash -n "${name}" ) )

if [[ "${sharded}" == "1" ]] 
then
    ecs=$( printf $ics | sed -e "s?:2701.?:${hn#*:}?g" )
else
    ecs=$( printf $ics | sed -e "s?@.*/?@${hn[0]},${hn[1]},${hn[2]}/?" )
fi
fi

tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security}' )
if [[ ${serviceType} != "" && ${internal} = 0 ]]
then
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"refix"* || "${tls}" == *"ecret"* || "${tls}" == *\"ca\":* ]]
then
    test -e "${PWD}/certs/ca.pem"               || kubectl get configmap ca-pem -o jsonpath="{.data['ca-pem']}" > "${PWD}/certs/ca.pem"
    test -e "${PWD}/certs/${name}${mongos}.pem" || kubectl get secret mdb-${name}${mongos}-cert-pem -o jsonpath="{.data.*}" | base64 --decode > "${PWD}/certs/${name}${mongos}.pem"
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile \"${PWD}/certs/ca.pem\" --sslPEMKeyFile \"${PWD}/certs/${name}${mongos}.pem\" "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile \"${PWD}/certs/ca.pem\" --tlsCertificateKeyFile \"${PWD}/certs/${name}${mongos}.pem\" "
        ssltls_enabled="&tls=true"
    fi
fi
    fcs=\'${ecs}${ssltls_enabled}\'
    printf "%s\n" "The connection string (external): ${fcs} ${ssltls_options}"

else # internal
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"refix"* || "${tls}" == *"ecret"* || "${tls}" == *\"ca\":* ]]
then
    #eval serverpem=$( kubectl get secret mdb-${name}${mongos}-cert-pem -o json |jq ".data"| jq "keys[]" )
    kv=$( kubectl get secret mdb-${name}${mongos}-cert-pem -o jsonpath="{.data}" | grep -o '".*":*' )
    serverpem=$( eval printf ${kv%:*} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile /mongodb-automation/tls/ca/ca-pem --sslPEMKeyFile /mongodb-automation/tls/${serverpem}"
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile /mongodb-automation/tls/ca/ca-pem --tlsCertificateKeyFile /mongodb-automation/tls/${serverpem}"
        ssltls_enabled="&tls=true"
    fi
fi
    fcs=\'${ics}${ssltls_enabled}\'
    printf "%s\n" "The connection string (internal): ${fcs} ${ssltls_options}"
fi
