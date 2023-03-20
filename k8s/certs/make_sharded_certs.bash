#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-mysharded-mysharded}
shift
ctype=${1}
shift
cert=${1}

comp=${ctype}
if [[ "$ctype" == "config" ]] ; then comp="cs" ; fi
if [[ "$ctype" == [012356] ]] ; then comp="sh" ; fi
if [[ "$ctype" == "mongos" ]] ; then comp="svc"; fi

# use wildcard vs individual certs now
"$PWD/gen_cert.bash" "mdb-${name}-${ctype}${cert}" "${namespace}" "*.${name}-${comp}.${namespace}.svc.cluster.local" 
