#!/bin/bash

source init.conf
name=${1:-my-replica-set}

tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == "{\"enabled\":true}" ]]
then
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile /mongodb-automation/ca.pem --sslPEMKeyFile /mongodb-automation/server.pem"
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem"
        ssltls_enabled="&tls=true"
    fi
fi

eval cs=mongodb://${dbadmin}:${dbpassword}@${name}-0:27017/?replicaSet=${name}
fcs=\'${cs}${ssltls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${ssltls_options}"
eval "kubectl exec ${name}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo ${fcs} ${ssltls_options}"
