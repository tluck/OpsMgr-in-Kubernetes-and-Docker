#!/bin/bash

source init.conf

# get NodePort
out0=( $(kubectl get svc/my-replica-set-0  | grep -v NAME) )
out1=( $(kubectl get svc/my-replica-set-1  | grep -v NAME) )
out2=( $(kubectl get svc/my-replica-set-2  | grep -v NAME) )
np0=${out0[4]:6:5}
np1=${out1[4]:6:5}
np2=${out2[4]:6:5}

# get DNS names
out=( $(kubectl describe nodes|grep ExternalDNS) )
if [[ $out == "" ]]
then
    out=( x localhost x localhost x localhost )
fi

# get keys for TLS
kubectl exec my-replica-set-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
kubectl exec my-replica-set-0 -i -t -- cat /mongodb-automation/server.pem > server.pem

printf "%s\n" "Connect String: mongodb://${out[1]}:$np0,${out[3]}:$np1,${out[5]}:$np2/?replicaSet=my-replica-set --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem -u <dbadmin> -p <dbpassword>"
mongo mongodb://${out[1]}:$np0,${out[3]}:$np1,${out[5]}:$np2/?replicaSet=my-replica-set --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem -u $dbadmin -p $dbpassword
