#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name="$1"
if [[ "$name" == "" ]]
then
    printf "%s\n" "Exit - need resource name"
    exit 1
fi
cname="$2"

# generate $name.pem

if [[ ! -e ${name}.pem ]]
then
printf "%s\n" "Making ${name}.pem ..."

kubectl delete csr ${name}.mongodb > /dev/null 2>&1

# generate request

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "${cname}",
    "${name}"
  ],
  "CN": "system:node:${cname}",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
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
  # signerName: kubernetes.io/kube-apiserver-client
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
EOF

# approve csr 
kubectl certificate approve ${name}.mongodb
kubectl get csr ${name}.mongodb

# get certs and build pem
eval c=$( kubectl get csr ${name}.mongodb -o json|jq .status.certificate)
echo $c |base64 -D> ${name}.crt
cat ${name}.key ${name}.crt > ${name}.pem

# clean up
rm ${name}.key
rm ${name}.crt
rm ${name}.csr

printf "%s\n\n" "Made ${name}.pem"
fi
