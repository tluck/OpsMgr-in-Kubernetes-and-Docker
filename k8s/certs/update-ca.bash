#!/bin/bash

source init.conf

cd certs
if [ "$1" == "-d" ]
then
    openssl s_client -showcerts -verify 2 -connect downloads.mongodb.com:443 \
        -servername downloads.mongodb.com </dev/null | awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; out="dlcert"a".crt"; print >out}' || true
    cat dlcert?.crt > downloads.crt 
    rm dlcert?.crt
fi
# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca.pem
cd ..

kubectl delete configmap ca-pem > /dev/null 2>&1
kubectl create configmap ca-pem  --from-file="ca-pem=${PWD}/certs/ca.pem"

kubectl delete configmap ${omName}-ca > /dev/null 2>&1
kubectl create configmap ${omName}-ca --from-file="ca-pem=${PWD}/certs/ca.pem" --from-file="mms-ca.crt=${PWD}/certs/ca.pem" 

