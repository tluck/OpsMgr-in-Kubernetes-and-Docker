#!/bin/bash

kubectl delete configmap shareddata
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

kubectl delete pods mongodb-1 mongodb-2 mongodb-3 
kubectl delete svc  mongodb-1 mongodb-2 mongodb-3 

cat node.yaml | sed -e 's/NAME/mongodb-1/' | kubectl apply -f -
cat node.yaml | sed -e 's/NAME/mongodb-2/' | kubectl apply -f -
cat node.yaml | sed -e 's/NAME/mongodb-3/' | kubectl apply -f -
