#!/bin/bash

# opsmanager
i=svc
name=opsmanager-${i}
if [[ ! -e ${name}-pem ]]
then
kubectl delete csr ${name}.mongodb

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
cat ${name}.crt ${name}.key > ${name}-pem
cp ${name}-pem server.pem
# clean up
rm ${name}.key
rm ${name}.crt
rm ${name}.csr
fi

# ------- opsmanager-db (app-db) -------
if [[ ! -e opsmanager-db-0-pem ]]
then
for i in 0 1 2;
do
name=opsmanager-db-${i}
kubectl delete csr ${name}.mongodb

host=${name}.opsmanager-db-svc.mongodb.svc.cluster.local

cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "${name}.opsmanager-db-svc.mongodb.svc.cluster.local",
    "${name}"
  ],
  "CN": "${name}.opsmanager-db-svc.mongodb.svc.cluster.local",
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
cat ${name}.crt ${name}.key > ${name}-pem
# clean up
rm ${name}.key
rm ${name}.crt
rm ${name}.csr
done
fi
