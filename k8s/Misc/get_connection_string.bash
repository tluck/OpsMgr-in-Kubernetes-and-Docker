#!/bin/bash

source init.conf
PATH=.:Misc:$PATH

while getopts 'n:srh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    s|r) sharded="1" ;;
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
    serviceType=$( kubectl get svc/${name}-svc-external -o jsonpath='{.spec.type}' 2>/dev/null )
else
    serviceType=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.type}' 2>/dev/null )
fi

#cs="mongodb://${dbadmin}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin"
ics=$( kubectl get secret ${name}-dbadmin-${name}-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
ecs="${ics}"
if [[ ${serviceType} != "" ]]
then
hn=( $( get_hns.bash -n "${name}" -t "${serviceType}" $mongos ) )

if [[ "${sharded}" == "1" ]] 
then
    ecs=$( printf $ics | sed -e "s?:2701.?:${hn#*:}?g" )
else
    ecs=$( printf $ics | sed -e "s?@.*/?@${hn[0]},${hn[1]},${hn[2]}/?" )
fi
fi

tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.authentication}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"\"enabled\":true"* || "${tls}" == *"prefix"* ]]
then
    test -e certs/ca.pem      || kubectl get configmap ca-pem -o jsonpath="{.data['ca-pem']}" > certs/ca.pem
    test -e certs/${name}.pem || kubectl get secret mdb-${name}-cert-pem -o jsonpath="{.data.*}" | base64 --decode > certs/${name}.pem
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile certs/ca.pem --sslPEMKeyFile certs/${name}.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile certs/ca.pem --tlsCertificateKeyFile certs/${name}.pem "
        ssltls_enabled="&tls=true"
    fi
fi

if [[ ${serviceType} == "" ]]
then
    fcs=\'${ics}${ssltls_enabled}\'
    printf "%s\n" "The connection string (internal): ${fcs} ${ssltls_options}"
else
    fcs=\'${ecs}${ssltls_enabled}\'
    printf "%s\n" "The connection string (external): ${fcs} ${ssltls_options}"
fi
