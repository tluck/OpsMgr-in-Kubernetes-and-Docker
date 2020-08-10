#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-opsmanager}

# OM
generate_cert.bash ${name}-svc ${name}-svc.mongodb.svc.cluster.local
ln -f ${name}-svc.pem server.pem

# app db
for i in 0 1 2
do
generate_cert.bash ${name}-db-${i} ${name}-db-${i}.${name}-db-svc.mongodb.svc.cluster.local
ln -f ${name}-db-${i}.pem ${name}-db-${i}-pem
done

# proxy server for backups
generate_cert.bash ${name}-proxy ${name}-proxy.mongodb.svc.cluster.local