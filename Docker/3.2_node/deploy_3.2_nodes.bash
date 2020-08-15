#!/bin/bash

kubectl delete configmap shareddata
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

kubectl delete pods mongodb1 mongodb2 mongodb3 
kubectl delete svc  mongodb1 mongodb2 mongodb3 
#kubectl apply -f svc.yaml

cat node.yaml | sed -e 's/NAME/mongodb1/' | kubectl apply -f -
cat node.yaml | sed -e 's/NAME/mongodb2/' | kubectl apply -f -
cat node.yaml | sed -e 's/NAME/mongodb3/' | kubectl apply -f -
