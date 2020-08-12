#!/bin/bash

fn="$1"
if [[ "${fn}" == "" ]]
then
    printf "%s\n" "Exit - need yaml file argument"
    exit 1
fi

s=( $( grep " name" "${fn}") )
name="${s[1]}"

source init.conf

# remove any old services
kubectl delete svc ${name}-0 ${name}-1 ${name}-2 > /dev/null 2>&1
#create nodeport service
if [[ "${horizon}" == "LoadBalancer" ]]
then
    kubectl apply -f svc_lb_${name}.yaml
else
    kubectl apply -f svc_np_${name}.yaml
fi

# kubectl expose pod ${name}-0 --type="LoadBalancer" --port 27017 -n mongodb
# kubectl expose pod ${name}-1 --type="LoadBalancer" --port 27017 -n mongodb
# kubectl expose pod ${name}-2 --type="LoadBalancer" --port 27017 -n mongodb

printf "%s\n" "Sleeping 20 seconds to allow IP/Hostnames to be created"
sleep 20
kubectl get svc ${name}-0 ${name}-1 ${name}-2

np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )

sn0=$( kubectl get svc/${name}-0 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' )
sn1=$( kubectl get svc/${name}-1 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' )
sn2=$( kubectl get svc/${name}-2 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' )

# get IP/DNS names
hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
if [[ ${hostname[0]} == "docker-desktop" ]]
then
    dnlist=( "localhost" "localhost" "localhost" )
else
    dnlist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    if [[ ${#dnlist[@]} == 0 ]] 
    then
        dnlist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
    fi
fi

hn0=${dnlist[0]}
hn1=${dnlist[1]}
hn2=${dnlist[2]}

num=${#dnlist[@]}

if [[ "$horizon" == "LoadBalancer" ]]
then
    cat "$fn" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
    echo "  connectivity:"                         | tee -a new
    echo "    replicaSetHorizons:"                 | tee -a new
    echo "      -" \"horizon-1\": \"${sn0}:27017\" | tee -a new
    echo "      -" \"horizon-1\": \"${sn1}:27017\" | tee -a new
    echo "      -" \"horizon-1\": \"${sn2}:27017\" | tee -a new
    mv new "$fn"

    cat init.conf | sed -e "/${name//-/}_URI/d" > new
    echo
    echo "${name//-/}_URI=\"mongodb://${sn0}:27017,${sn1}:27017,$sn2}:27017/?replicaSet=${name} -u \$dbadmin -p \$dbpassword --authenticationDatabase admin \" " | tee -a new
    echo
    mv new init.conf
else
    cat "$fn" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
    echo "  connectivity:"                        | tee -a new
    echo "    replicaSetHorizons:"                | tee -a new
    echo "      -" \"horizon-1\": \"${hn0}:$np0\" | tee -a new
    echo "      -" \"horizon-1\": \"${hn1}:$np1\" | tee -a new
    echo "      -" \"horizon-1\": \"${hn2}:$np2\" | tee -a new
    mv new "$fn"

    cat init.conf | sed -e "/${name//-/}_URI/d" > new
    echo
    echo "${name//-/}_URI=\"mongodb://${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name} -u \$dbadmin -p \$dbpassword --authenticationDatabase admin \" " | tee -a new
    echo
    mv new init.conf
fi
