#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-my-replica-set}
source ../init.conf

if [[ "$horizon" == "LoadBalancer" ]]
then
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].port}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].port}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].port}' )

    slist=( $( kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}' ) )
    if [[ ${#slist[@]} == 0 ]]
    then
        slist=( $(kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip }' ) )
    fi
else
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )

# get IP/DNS names
    hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
    if [[ ${hostname[0]} == "docker-desktop" ]]
    then
        slist=( "localhost" "localhost" "localhost" )
    else
        slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
        # get node external IPs
       if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi
    fi

fi

num=${#slist[@]}

if [[ $num = 0 ]]
then
    printf "%s\n" -- "Can't create split horizon map - exiting"
    exit 1
fi

if [[ $num = 1 ]]
then
# single node cluster
    hn0=${slist[0]}
    hn1=${slist[0]}
    hn2=${slist[0]}
else
    hn0=${slist[0]}
    hn1=${slist[1]}
    hn2=${slist[2]}
fi

horizon=(hn0 hn1 hn2)

# db
for i in 0 1 2
do
# 3 names
generate_db_cert.bash ${name}-${i} ${name}-${i}.${name}-svc.mongodb.svc.cluster.local ${horizon[$i]}
ln -f ${name}-${i}.pem ${name}-${i}-pem
done

