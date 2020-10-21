#!/bin/bash

source init.conf
name=${1:-my-replica-set}

# get keys for TLS
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == "{\"enabled\":true}" ]]
then
    kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
    kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/server.pem > server.pem
    tls_options=" --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
    tls_enabled="&tls=true"
fi

eval cs=\$${name//-/}_URI
fcs=\'${cs}${tls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${tls_options}"
eval "mongo ${fcs} ${tls_options}"
