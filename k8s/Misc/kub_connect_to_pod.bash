#!/bin/bash -x

source init.conf
name=${1:-my-replica-set}

if [[ "$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )" == 'map[enabled:true]' ]]
then
tls_options="--tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem "
fi

string="kubectl exec ${name}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=${name} -u $dbadmin -p $dbpassword --authenticationDatabase admin $tls_options"
#kubectl exec my-replica-set-0 -i -t -- /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.2.6-ent/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=my-replica-set --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem -u dbAdmin -p Mongodb1$ 
#kubectl exec ${name}-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=${name} -u $dbadmin -p $dbpassword --authenticationDatabase admin --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem
eval $string