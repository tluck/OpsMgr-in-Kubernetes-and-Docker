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
#"$PWD/gen_cert.bash" "mdb-${name}-${ctype}${cert}" "*.${name}-${comp}.${namespace}.svc.${clusterDomain}" 

members=3 # hard coded in template
n=0
while [ $n -lt $members ]
do
    names[$n]="${name}-${ctype}-${n}.${name}-${comp}.${namespace}.svc.${clusterDomain}"
    n=$((n+1))
done
"$PWD/gen_cert.bash" "mdb-${name}-${ctype}${cert}" ${names[*]}
