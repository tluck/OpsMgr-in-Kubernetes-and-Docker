#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

# docker-desktop
kubectl cp kube-system/kube-apiserver-docker-desktop:/run/config/pki/ca.crt ca.crt
kubectl cp kube-system/kube-apiserver-docker-desktop:/run/config/pki/ca.key ca.key

#kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt

# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca-pem
ln -f ca-pem mms-ca.crt 

name=${1:-opsmanager}

# proxy server for backups
#x.bash
generate_cert.bash ${name}-svc ${name}-svc.mongodb.svc.cluster.local
cat ${name}-svc.pem ca.key ca.crt > queryable-backup.pem
rm ${name}-svc.pem


