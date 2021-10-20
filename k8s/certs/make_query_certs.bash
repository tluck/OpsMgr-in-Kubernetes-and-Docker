#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

context=$( kubectl config current-context )
test -e ca.crt && rm ca.crt
test -e ca.key && rm ca.key
if [[ $context == docker-desktop ]]
then
# docker-desktop
    kubectl cp kube-system/etcd-docker-desktop:run/config/pki/etcd/ca.crt ca.crt
    kubectl cp kube-system/etcd-docker-desktop:run/config/pki/etcd/ca.key ca.key
else
# need a key and the cert for queriable backup -  ca.key and ca.crt
    kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt
fi

# add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
cat downloads.crt ca.crt > ca-pem
ln -f ca-pem mms-ca.crt 

name=${1:-opsmanager}

# proxy server for backups
#x.bash
if [[ -e ca.key ]]
then
    generate_cert.bash ${name}-svc ${name}-svc.mongodb.svc.cluster.local
    cat ${name}-svc.pem ca.key ca.crt > queryable-backup.pem
    rm ${name}-svc.pem
fi


