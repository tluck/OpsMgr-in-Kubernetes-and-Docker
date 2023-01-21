#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
name=${1:-opsmanager}

#def_token=( $( kubectl get secrets | grep default-token ) )
#kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt
#kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt

# creates ca.crt ca.key ca.csr
if [[ ! -e ca.pem ]]
then
    generate_ca.bash

    # add MongoDB Downloads cert to the k8s root cert (agents and opsmanager)
    cat downloads.crt ca.crt > ca.pem
    # ln -sf ca-pem mms-ca.crt
fi

# certs for the proxy server for queryable backup
if [[ ! -e queryable-backup.pem ]]
then
    generate_cert.bash ${name}-svc ${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${name}-backup-daemon-0.${name}-backup-daemon-svc.${namespace}.svc.cluster.local ${name}-backup-daemon-0
    cat ${name}-svc.pem ca.key ca.crt > queryable-backup.pem
    rm ${name}-svc.pem
fi

# OM
generate_cert.bash ${name}-svc ${name}-svc.${namespace}.svc.cluster.local ${om_ext}

# appdb
generate_cert.bash ${name}-db "*.${name}-db-svc.${namespace}.svc.cluster.local" 
