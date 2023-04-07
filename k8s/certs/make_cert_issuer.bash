#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
namespace=${1:-mynamespace}
issuerName=${2:-myissuer}
issuerVersion=${3}

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
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${issuerVersion}/cert-manager.yaml

kubectl delete secret ca-key-pair > /dev/null 2>&1
kubectl create secret tls ca-key-pair \
    --cert="ca.crt" \
    --key="ca.key"

printf "%s\n" "Waiting for the cert-manager ..."
# Create an issuer from the CA secret
code=1
n=0
while [ $code -eq 1 ]
do
sleep 20
kubectl delete Issuer/${issuerName} > /dev/null 2>&1
cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${issuerName}
  namespace: ${namespace}
spec:
  ca:
    secretName: ca-key-pair
EOF
code=$?
n=$((n+1))
if [[ "$n" > 20 ]] 
then
    printf "%s\n" "* * * - Error Launching Cert Issuer"
    exit 1
fi
done
printf "%s\n" "... Done"
exit 0
