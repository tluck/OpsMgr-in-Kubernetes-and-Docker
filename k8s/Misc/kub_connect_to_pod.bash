#!/bin/bash

source init.conf
name=${1:-myreplicaset}
mongos=${2:-"-mongos"}

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

#eval cs=mongodb://${dbadmin}:${dbpassword}@${name}-0:27017/?replicaSet=${name}
ics=$( kubectl get secret ${name}-dbadmin-${name}-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
fcs=\'${ics}${ssltls_enabled}\'
printf "\n%s %s\n\n" "Connect String: ${fcs} ${ssltls_options}"
eval "kubectl exec ${name}${mongos}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo ${fcs} ${ssltls_options}"
