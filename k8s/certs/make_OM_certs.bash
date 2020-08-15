#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

#def_token=( $( kubectl get secrets | grep default-token ) )
#kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt

kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt

# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca-pem
ln -f ca-pem mms-ca.crt 

name=${1:-opsmanager}

# OM
generate_cert.bash ${name}-svc ${name}-svc.mongodb.svc.cluster.local
ln -f ${name}-svc.pem server.pem

# app db
for i in 0 1 2
do
generate_cert.bash ${name}-db-${i} ${name}-db-${i}.${name}-db-svc.mongodb.svc.cluster.local
ln -f ${name}-db-${i}.pem ${name}-db-${i}-pem
done

