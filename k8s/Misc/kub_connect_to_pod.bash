#!/bin/bash -x

source init.conf
name=${1:-my-replica-set}

if [[ "$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )" == 'map[enabled:true]' ]]
then
    #tls_options="&tls=true&tlsCAFile=/mongodb-automation/ca.pem&tlsCertificateKeyFile=/mongodb-automation/server.pem"
    tls_options=" --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem"
fi

#string="kubectl exec ${name}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://${name}-0:27017/?replicaSet=${name} -u $dbadmin -p $dbpassword --authenticationDatabase admin $tls_options"
string="kubectl exec ${name}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://${dbadmin}:${dbpassword}@${name}-0:27017/admin?replicaSet=${name} $tls_options"
eval $string
