#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-opsmanager}

# proxy server for backups
#x.bash
if [[ -e ca.key ]]
then
    generate_cert.bash ${name}-svc ${name}-svc.${namespace}.svc.cluster.local
    cat ${name}-svc.pem ca.key ca.crt > queryable-backup.pem
    rm ${name}-svc.pem
fi


