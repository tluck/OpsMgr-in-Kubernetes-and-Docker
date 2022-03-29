#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-my-shard}
shift
ctype=${1}
comp=${ctype}
if [[ "$ctype" == "config" ]] ; then comp="cs" ; fi
if [[ "$ctype" == [012356] ]] ; then comp="sh" ; fi
if [[ "$ctype" == "mongos" ]] ; then comp="svc"; fi

# use wildcard vs individual certs now
generate_cert.bash ${name}-${ctype} "*.${name}-${comp}.mongodb.svc.cluster.local" 
