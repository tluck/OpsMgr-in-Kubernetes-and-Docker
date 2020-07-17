#!/bin/bash

source init.conf

# get keys for TLS
kubectl exec my-replica-set-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
kubectl exec my-replica-set-0 -i -t -- cat /mongodb-automation/server.pem > server.pem

printf "%s\n" "Connect String: ${mmyReplicaSetConnect}"
eval mongo ${myReplicaSetConnect} $@
