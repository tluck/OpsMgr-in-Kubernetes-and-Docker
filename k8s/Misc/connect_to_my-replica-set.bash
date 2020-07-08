#kubectl exec my-replica-set-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=my-replica-set
kubectl exec my-replica-set-0 -i -t -- /var/lib/mongodb-mms-automation/bin/mongo mongodb://my-replica-set-0:27017/?replicaSet=my-replica-set -ssl --sslCAFile /mongodb-automation/ca.pem --sslPEMKeyFile /mongodb-automation/server.pem -u dbAdmin -p Mongodb1$ 
