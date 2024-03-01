#!/bin/bash

source init.conf

while getopts 'n:mlih' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    i) internal=1     ;;
    l) ldap=1         ;;
    m) multiCluster="-m" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

ns="-n ${namespace}"
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
internal=${internal:-0}

type=$( kubectl $ns get ${mdbKind}/${name} -o jsonpath='{.spec.type}' )
#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    sharded=1
    mongos="-mongos"
    serviceType=$( kubectl $context $ns get svc/${name}${mongos}-0-svc-external -o jsonpath='{.spec.type}' 2>/dev/null )
else
    serviceType=$( kubectl $context $ns get svc/${name}${member}-0-svc-external -o jsonpath='{.spec.type}' 2>/dev/null )
fi

#cs="mongodb://${dbuser}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin"
ics=$( kubectl $context $ns get secret ${name}-${name}-admin-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
eval externalDomain=$( kubectl $ns get ${mdbKind} ${name} -o json | jq .spec.externalAccess.externalDomain ); 
# bug with connection string
if [[ ${externalDomain} != "null" ]]
then
    if [[ ${mdbKind} == "MongoDBMultiCluster" ]]
    then
    eval domainList=( $(kubectl $ns get ${mdbKind} ${name} -o json|jq .spec.clusterSpecList[].externalAccess.externalDomain ) )
    hn=( "${name}-0-0.${domainList[0]}" \
         "${name}-0-1.${domainList[0]}" \
         "${name}-1-0.${domainList[1]}" \
         "${name}-1-1.${domainList[1]}" \
         "${name}-2-0.${domainList[2]}" )
    ics=$( printf "%s" "$ics" | sed -e "s?@.*/?@${hn[0]},${hn[1]},${hn[2]},${hn[3]},${hn[4]}/?" )
    else
    hn=( "${name}-0.${externalDomain}" \
         "${name}-1.${externalDomain}" \
         "${name}-2.${externalDomain}" ) 
    ics=$( printf "%s" "$ics" | sed -e "s?@.*/?@${hn[0]},${hn[1]},${hn[2]}/?" )
    fi
fi

if [[ $ldap == 1 ]]
then
    ics=${ics/SCRAM-SHA-256/PLAIN}
    ics=${ics/admin/\%24external}
fi
ecs="${ics}"
if [[ ${serviceType} != "" ]]
then

if [[ ${sharded} == 1 ]] 
then
    hn=( $( get_hns.bash -s "${name}${mongos}-0-svc-external" ) )
    ecs=$( printf "%s" "$ics" | sed -e "s?:2701.?:${hn#*:}?g" )
elif [[ ${externalDomain} == "null" ]]
then
    hn=( $( get_hns.bash -n "${name}" ) )
    ecs=$( printf "%s" "$ics" | sed -e "s?@.*/?@${hn[0]},${hn[1]},${hn[2]}/?" )
fi
fi
# check to see is TLS on
spec=$( kubectl $ns get ${mdbKind}/${name} -o jsonpath='{.spec.security}' )
if [[ ${serviceType} != "" && ${internal} = 0 ]]
then
if [[ "${spec}" == "map[enabled:true]" || "${spec}" == *"refix":* || "${spec}" == *"ecret":* || "${spec}" == *\"ca\":* ]]
then
    test -e "${PWD}/certs/ca.pem"               || kubectl $context $ns get configmap ca-pem -o jsonpath="{.data['ca-pem']}" > "${PWD}/certs/ca.pem"
    #test -e "${PWD}/certs/${name}${mongos}.pem" || kubectl $ns get secret mdb-${name}${mongos}-cert-pem -o jsonpath="{.data.*}" | base64 --decode > "${PWD}/certs/${name}${mongos}.pem"
    kubectl $context $ns get secret mdb-${name}${mongos}-cert-pem -o jsonpath="{.data.*}" | base64 --decode > "${PWD}/certs/${name}${mongos}.pem"
    eval version=$( kubectl $ns get ${mdbKind} ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_enabled="&ssl=true&sslCAFile=${PWD}/certs/ca.pem&sslPEMKeyFile=${PWD}/certs/${name}${mongos}.pem "
        #ssltls_options=" --ssl true --sslCAFile \"${PWD}/certs/ca.pem\" --sslPEMKeyFile \"${PWD}/certs/${name}${mongos}.pem\" "
    else
        ssltls_enabled="&tls=true&tlsCAFile=${PWD}/certs/ca.pem&tlsCertificateKeyFile=${PWD}/certs/${name}${mongos}.pem "
        #ssltls_options=" --tls true --tlsCAFile \"${PWD}/certs/ca.pem\" --tlsCertificateKeyFile \"${PWD}/certs/${name}${mongos}.pem\" "
    fi
fi
    fcs=\'${ecs}${ssltls_enabled}\'
    printf "The connection string (external): "
    printf "%s\n" "${fcs}"

else # internal
if [[ "${spec}" == "map[enabled:true]" || "${spec}" == *"refix":* || "${spec}" == *"ecret":* || "${spec}" == *\"ca\":* ]]
then
    #eval serverpem=$( kubectl $context $ns get secret mdb-${name}${mongos}-cert-pem -o json |jq ".data"| jq "keys[]" )
    kv=$( kubectl $context $ns get secret mdb-${name}${mongos}-cert-pem -o jsonpath="{.data}" | grep -o '".*":*' )
    serverpem=$( eval printf ${kv%:*} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_enabled="&ssl=true&sslCAFile=/mongodb-automation/tls/ca/ca-pem&sslPEMKeyFile=/mongodb-automation/tls/${serverpem}"
        #ssltls_options=" --ssl true --sslCAFile /mongodb-automation/tls/ca/ca-pem --sslPEMKeyFile /mongodb-automation/tls/${serverpem}"
    else
        ssltls_enabled="&tls=true&tlsCAFile=/mongodb-automation/tls/ca/ca-pem&tlsCertificateKeyFile=/mongodb-automation/tls/${serverpem}"
        #ssltls_options=" --tls true --tlsCAFile /mongodb-automation/tls/ca/ca-pem --tlsCertificateKeyFile /mongodb-automation/tls/${serverpem}"
    fi
fi
    fcs=\'${ics}${ssltls_enabled}\'
    #printf "%s\n" "The connection string (internal): ${fcs} ${ssltls_options}"
    printf "The connection string (internal): "
    printf "%s\n" "${fcs}"
fi
