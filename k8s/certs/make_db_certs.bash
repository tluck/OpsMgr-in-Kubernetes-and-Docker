#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-my-replica-set}
shift
dnsHorizon=( $@ )

# use wildcard vs individual certs now
generate_cert.bash ${name} "*.${name}-svc.mongodb.svc.cluster.local" ${dnsHorizon[*]}

