#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name="$1"
if [[ "$name" == "" ]]
then
    printf "%s\n" "Exit - need resource name"
    exit 1
fi

# get the Root CA - got to be better way
def_token=( $( kubectl get secrets | grep default-token ) )
kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt 

# concatenate MongoDB downloads and the K8s ca.crt
# OM and AppDB need these 2 items
cat downloads.crt ca.crt > ca-pem
cat downloads.crt ca.crt > mms-ca.crt 

# generate $name-pem

if [[ ! -e ${name}.pem ]]
then
printf "%s\n" "Making ${name}.pem ..."

kubectl delete csr ${name}.mongodb > /dev/null 2>&1

# generate request

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "${name}.mongodb.svc.cluster.local",
    "${name}"
  ],
  "CN": "${name}.mongodb.svc.cluster.local",
  "key": {
    "algo": "rsa",
    "size": 4096
  }
}
EOF
mv server-key.pem ${name}.key
mv server.csr ${name}.csr

# submit cert request (csr)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${name}.mongodb
spec:
  request: $(cat ${name}.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
EOF

# approve csr 
kubectl certificate approve ${name}.mongodb

# get certs and build pem
eval c=$( kubectl get csr ${name}.mongodb -o json|jq .status.certificate)
echo $c |base64 -D> ${name}.crt
cat ${name}.crt ${name}.key > ${name}.pem

# clean up
rm ${name}.key
rm ${name}.crt
rm ${name}.csr
fi

if [[ -e ${name}.pem ]]
then
  printf "%s\n\n" "Made ${name}.pem ..."
fi
