#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

name=${1:-myreplicaset}
shift
dnsHorizon=( $@ )

# use wildcard vs individual certs now
generate_cert.bash "${name}" "*.${name}-svc.${namespace}.svc.cluster.local" ${dnsHorizon[*]}

