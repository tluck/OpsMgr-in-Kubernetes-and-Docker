#!/bin/bash

. init.conf

kubectl delete secret dbadmin-secret
kubectl create secret generic dbadmin-secret \
  --from-literal=name="dbAdmin" \
  --from-literal=password="${password}"

kubectl apply -f ops-mgr-resource-database-user-conf.yaml
