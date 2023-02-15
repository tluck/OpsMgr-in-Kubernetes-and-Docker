#!/bin/bash

source init.conf
kubectl -n $namespace delete secret openldap  > /dev/null 2>&1 
kubectl -n $namespace create secret generic openldap \
    --from-literal=adminpassword=adminpassword \
    --from-literal=users=dbAdmin,user01,user02 \
    --from-literal=passwords=Mongodb1,Mongodb1,Mongodb1
kubectl -n $namespace delete svc openldap openldap-svc-ext > /dev/null 2>&1 
kubectl -n $namespace delete Deployment openldap  > /dev/null 2>&1 
kubectl -n $namespace create -f openldap.yaml -n $namespace
