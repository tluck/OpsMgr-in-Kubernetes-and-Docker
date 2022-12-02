#!/bin/bash

while getopts 'n:t:h' opts
do
  case "$opts" in
    n) name="$OPTARG" ;;
    t) serviceType="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] [-t NodePort|LoadBalancer ] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myreplicaset}
serviceType=${serviceType:-NodePort}

type=$( kubectl get mdb/${name} -o jsonpath='{.spec.type}' 2>/dev/null )
#if [[ "${sharded}" == "1" ]]
if [[ "${type}" == "ShardedCluster" ]]
then
    sharded=1
fi

if [[ "${sharded}" == 1 ]]
then
    serviceType=$( kubectl get svc/${name}-svc-external -o jsonpath='{.spec.type}' )
else
    serviceType=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.type}' )
fi
if [[ "$serviceType" != "NodePort" ]]
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
    if [[ "${sharded}" == 1 ]]
    then
    np0=$( kubectl get svc/${name}-svc-external -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$np0
    np2=$np0
    else
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )
    fi # not sharded

fi
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
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalDNS")].address}' ) )
        fi
    if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi
    fi


num=${#slist[@]}

if [[ $num = 1 ]]
then
# single node cluster
    hn0=${slist[0]}
    hn1=${slist[0]#}
    hn2=${slist[0]#}
else
    hn0=${slist[0]}
    hn1=${slist[1]}
    hn2=${slist[2]}
fi
printf "%s %s %s" "$hn0:$np0" "$hn1:$np1" "$hn2:$np2" 
