#!/bin/bash

source init.conf
name=${1:-my-replica-set}

# get keys for TLS
kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/server.pem > server.pem
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == "{\"enabled\":true}" ]]
then
    #tls_options="--tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
    #tls_options="&tls=true&tlsCAFile=ca.pem&tlsCertificateKeyFile=server.pem"
    tls_options="&tls=true"
fi

eval cs=\$${name//-/}_URI
fcs=\'${cs}${tls_options}\'
printf "\n%s\n\n" "Connect String: ${fcs}"
eval mongo "${fcs}"
