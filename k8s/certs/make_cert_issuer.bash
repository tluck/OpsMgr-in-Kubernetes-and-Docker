#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
namespace=${1:-mynamespace}
issuerName=${2:-myIssuer}

# creates ca.crt ca.key ca.csr
[[ ! -e ca.crt ]] && generate_ca.bash

if [[ ! -e ca.pem ]]
then
    # download.com cert
    openssl s_client -showcerts -verify 2 -connect downloads.mongodb.com:443 \
        -servername downloads.mongodb.com </dev/null | awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; out="dlcert"a".crt"; print >out}' || true
    cat dlcert?.crt > downloads.crt 
    rm dlcert?.crt
    # add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
    cat downloads.crt ca.crt > ca.pem
fi

# Create a map for the ca
kubectl delete configmap ca-pem > /dev/null 2>&1
kubectl create configmap ca-pem \
    --from-file="ca-pem=ca.pem"

# get the cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

kubectl delete secret ca-key-pair > /dev/null 2>&1
kubectl create secret tls ca-key-pair \
    --cert="ca.crt" \
    --key="ca.key"

sleep 5

# Create an issuer from the CA secret
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${issuerName}
  namespace: ${mynamespace}
spec:
  ca:
    secretName: ca-key-pair
EOF
