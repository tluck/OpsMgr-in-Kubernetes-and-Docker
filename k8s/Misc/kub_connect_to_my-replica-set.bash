#!/bin/bash

source init.conf

#kubectl exec my-replica-set-0 -i -t -- /var/lib/mongodb-mms-automation/mongodb-linux-x86_64-4.2.6-ent/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=my-replica-set --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem -u dbAdmin -p Mongodb1$ 
kubectl exec my-replica-set-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=my-replica-set --tls --tlsCAFile /mongodb-automation/ca.pem --tlsCertificateKeyFile /mongodb-automation/server.pem -u "$dbadmin" -p "$dbpassword" --authenticationDatabase admin $@
