#!/bin/bash

# get latest cert
cp ../../k8s/certs/ca-pem data/ca.pem

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

name=node-
for i in 1 2 3 4 5 6 7 8 9 0
do
kubectl delete pod ${name}${i} > /dev/null 2>&1
kubectl delete svc ${name}${i} > /dev/null 2>&1
cat node.yaml | sed -e "s/NAME/${name}${i}/" | kubectl apply -f -
done
