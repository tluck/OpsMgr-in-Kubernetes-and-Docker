#!/bin/bash

source init.conf
name=${1:-my-replica-set}

# get keys for TLS
kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/server.pem > server.pem

if [[ "$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )" == "map[enabled:true]" ]]
then
    #tls_options="--tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
    tls_options="&tls=true&tlsCAFile=ca.pem&tlsCertificateKeyFile=server.pem"
fi

eval cs=\$${name//-/}_URI
printf "\n%s\n\n" "Connect String: ${cs}${tls_options}"
fcs=\'${cs}${tls_options}\'
eval mongo "${fcs}"
