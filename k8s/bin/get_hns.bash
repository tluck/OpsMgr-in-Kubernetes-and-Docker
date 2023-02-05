#!/bin/bash

while getopts 'n:h' opts
do
  case "$opts" in
    n) name="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) -n Name "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#name=${name:-myreplicaset}

# Check if this is for a cluster otherwise assume it is the OM
serviceName=${name}-0
type=$( kubectl get mdb/${name} -o jsonpath='{.spec.type}' 2>/dev/null )
err1=$?
if [[ $err1 != 0 ]]
then
    om=1
    serviceType=$( kubectl get om/${name} -o jsonpath='{.spec.externalConnectivity.type}' 2>/dev/null )
    err2=$?
    if [[ $err2 == 0 ]] 
    then
        serviceName=${name}-svc-ext
    fi
else

om=0
if [[ "${type}" == "ShardedCluster" ]]
then
    serviceName=${name}-svc-external
fi
fi

serviceType=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.type}' 2>/dev/null )
err3=$?

if [[ $err1 != 0 && $err2 != 0 && $err3 != 0 ]]
then
        printf "\n%s\n\n", "* * * Error - Service ${serviceName} for $name was not found"
        exit 1
fi

if [[ "$serviceType" != "NodePort" ]]
then
    if [[ "${type}" == "ShardedCluster" || ${om} == 1 ]]
    then
        np0=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.ports[0].port}' )
        slist=( $( kubectl get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ) )
        if [[ ${#slist[@]} == 0 ]]
        then
        slist=( $(kubectl get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[*].ip }' ) )
        fi
    else
        np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].port}' )
        np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].port}' )
        np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].port}' )

        slist=( $( kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}' ) )
        if [[ ${#slist[@]} == 0 ]]
        then
        slist=( $(kubectl get svc ${name}-0 ${name}-1 ${name}-2 -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip }' ) )
        fi
    fi
else
    if [[ "${type}" == "ShardedCluster" || ${om} == 1 ]]
    then
    np0=$( kubectl get svc/${serviceName} -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$np0
    np2=$np0
    else
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )
    fi # not sharded
fi

if [[ "$serviceType" != "LoadBalancer" ]]
then
# get IP/DNS names
    #slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
    if [[ ${slist[0]} == "docker-desktop" ]]
    then
	slist=( "localhost" ) 
    else
        slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    	if [[ ${#slist[@]} == 0 ]] 
        then
    	    slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
	fi
    	if [[ ${#slist[@]} == 0 && $custerType == "openshift" ]]
	then
            # OpenShift read of names
	    # slist=( $( kubectl get nodes -o json | jq -r '.items[].metadata.labels | select(."node-role.kubernetes.io/worker") | ."kubernetes.io/hostname" '))
            slist=( $(kubectl get nodes -o json | jq -r '.items[].metadata.labels | select((."node-role.kubernetes.io/infra" == null) and .storage == "pmem") | ."kubernetes.io/hostname" ' ) ) 
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalDNS")].address}' ) )
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi
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
