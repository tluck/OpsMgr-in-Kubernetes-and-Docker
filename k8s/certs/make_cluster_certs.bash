#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-myreplicaset-myreplicaset}
shift
dnsHorizon=( $@ )

# use wildcard vs individual certs now
"$PWD/gen_cert.bash" "mdb-${name}-cert" "*.${name}-svc.${namespace}.svc.cluster.local" ${dnsHorizon[*]}
