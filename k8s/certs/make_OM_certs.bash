#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

#def_token=( $( kubectl get secrets | grep default-token ) )
#kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt
#kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt

# creates ca.crt ca.key ca.csr
generate_ca.bash

# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca-pem
ln -f ca-pem mms-ca.crt 

name=${1:-opsmanager}

# OM
generate_cert.bash ${name}-svc ${name}-svc.mongodb.svc.cluster.local

# appdb
generate_cert.bash ${name}-db "*.${name}-db-svc.mongodb.svc.cluster.local" 

# for OM 
ln -f ${name}-svc.pem server.pem

