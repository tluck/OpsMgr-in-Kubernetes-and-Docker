#!/bin/bash

source init.conf
name=${1:-my-replica-set}

# get keys for TLS
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == "{\"enabled\":true}" ]]
then
    kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
    kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/server.pem > server.pem
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile ca.pem --sslPEMKeyFile server.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
        ssltls_enabled="&tls=true"
    fi
fi

eval cs=\$${name//-/}_URI
fcs=\'${cs}${ssltls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${ssltls_options}"
eval "mongo ${fcs} ${ssltls_options}"
