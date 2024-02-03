#!/bin/bash

source init.conf

cd certs
if [[ "$1" == "-d" || ! -e downloads.crt ]]
then
    openssl s_client -showcerts -verify 2 -connect downloads.mongodb.com:443 \
        -servername downloads.mongodb.com </dev/null | awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; out="dlcert"a".crt"; print >out}' || true
    cat dlcert?.crt > downloads.crt 
    rm dlcert?.crt
fi
# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca.pem
cd ..

rm "${PWD}/certs/queryable-backup.pem" "${PWD}/certs/${omName}-svc.pem" 

kubectl delete configmap ca-pem > /dev/null 2>&1
kubectl create configmap ca-pem  --from-file="ca-pem=${PWD}/certs/ca.pem"

kubectl delete configmap ${omName}-ca > /dev/null 2>&1
kubectl create configmap ${omName}-ca --from-file="ca-pem=${PWD}/certs/ca.pem" --from-file="mms-ca.crt=${PWD}/certs/ca.pem" 

"${PWD}/certs/make_OM_certs.bash" ${omName}

# delete all secrets except key-pair
kubectl get secrets | grep kubernetes | grep -v ca-key-pair | awk '{print $1}' | xargs -n 1 kubectl delete secret

kubectl delete secret         ${omName}-cert > /dev/null 2>&1
kubectl create secret generic ${omName}-cert \
        --from-file="server.pem=${PWD}/certs/${omName}-svc.pem" \
        --from-file="${PWD}/certs/queryable-backup.pem" \
        --from-file="ca-pem=${PWD}/certs/ca.pem" \
        --from-file="mms-ca.crt=${PWD}/certs/ca.pem"

exit

# cert manager 
kubectl delete secret ca-key-pair > /dev/null 2>&1
kubectl create secret tls ca-key-pair \
    --cert="${PWD}/certs/ca.crt" \
    --key="${PWD}/certs/ca.key"

certs/make_cert_issuer.bash ${namespace} ${issuerName} ${issuerVersion}
