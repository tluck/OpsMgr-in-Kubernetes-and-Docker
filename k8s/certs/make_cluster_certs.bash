#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-myproject1-myreplicaset}
shift
dnsHorizon=( $@ )

# use wildcard vs individual certs now
#"$PWD/gen_cert.bash" "mdb-${name}-cert" "*.${name}-svc.${namespace}.svc.cluster.local" ${dnsHorizon[*]}

# members=$( kubectl get mdb ${name} -o json|jq .spec.members )
members=3 # hard coded in template
n=0
while [ $n -lt $members ]
do
    names[$n]="${name}-${n}.${name}-svc.${namespace}.svc.cluster.local"
    n=$((n+1))
done

"$PWD/gen_cert.bash" "mdb-${name}-cert" ${names[*]} ${dnsHorizon[*]}
