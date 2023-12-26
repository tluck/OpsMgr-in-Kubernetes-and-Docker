#!/bin/bash

source init.conf

while getopts 'n:s:h' opts
do
  case "$opts" in
    n) name="$OPTARG" ;;
    s) sName="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) -n Name "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

#name=${name:-myproject1-myreplicaset}

# Check if this is for a cluster otherwise assume it is the OM

serviceName=""
if [[ $name != "" ]] 
then
    serviceName=${name}-0-svc-external
    type=$( kubectl -n ${namespace} get mdb/${name} -o jsonpath='{.spec.type}' 2>/dev/null )
    err1=$?
    if [[ $err1 != 0 ]]
    then
        serviceType=$( kubectl -n ${namespace} get om/${name} -o jsonpath='{.spec.externalConnectivity.type}' 2>/dev/null )
        err2=$?
        if [[ $err2 == 0 ]] 
        then
            om=1
            serviceName=${name}-svc-ext
        fi
    else # we assume RepSet but lets check for RepSet vs Sharded
        om=0
        if [[ "${type}" == "ShardedCluster" ]]
        then
            serviceName=${name}-svc-external
        fi
    fi
else
    serviceName=$sName
    om=1
fi

serviceType=$( kubectl -n ${namespace} get svc/${serviceName} -o jsonpath='{.spec.type}' 2>/dev/null )
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
        slist=( $( kubectl -n ${namespace} get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ) )
        if [[ ${#slist[@]} == 0 ]]
        then
        iplist=( $(kubectl -n ${namespace} get svc/${serviceName} -o jsonpath='{.status.loadBalancer.ingress[*].ip }' ) )
        fi
    else
        slist=( $( kubectl -n ${namespace} get $( kubectl -n ${namespace} get svc -o name |grep "${name}.*external" )  -o jsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}' ) )
        if [[ ${#slist[@]} == 0 ]]
        then
        iplist=( $(kubectl -n ${namespace} get $( kubectl -n ${namespace} get svc -o name |grep "${name}.*external" )  -o jsonpath='{.items[*].status.loadBalancer.ingress[*].ip }' ) )
        fi
    fi
fi

if [[ "$serviceType" != "LoadBalancer" ]]
then
# get IP/DNS names
    #slist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    slist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
    if [[ ${slist[0]} == "docker-desktop" ]]
    then
	slist=( "localhost" ) 
    else
        slist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
    	if [[ ${#slist[@]} == 0 ]] 
        then
    	    slist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
	    fi
        if [[ ${#slist[@]} == 0 ]] 
        then
            iplist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi

    if [[ ${#slist[@]} == 0 && $custerType == "openshift" ]]
	then
            # OpenShift read of names
	    # slist=( $( kubectl -n ${namespace} get nodes -o json | jq -r '.items[].metadata.labels | select(."node-role.kubernetes.io/worker") | ."kubernetes.io/hostname" '))
            slist=( $(kubectl -n ${namespace} get nodes -o json | jq -r '.items[].metadata.labels | select((."node-role.kubernetes.io/infra" == null) and .storage == "pmem") | ."kubernetes.io/hostname" ' ) ) 
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            slist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalDNS")].address}' ) )
        fi
    	if [[ ${#slist[@]} == 0 ]] 
        then
            iplist=( $(kubectl -n ${namespace} get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
        fi
    fi
    
fi

num=${#iplist[@]}
if [[ $num == 0 ]]
then
n=0
for h in ${slist[*]}
do 
    out=( $( nslookup $h|grep -i Address ))
    iplist[$n]=${out[3]}
    n=$((n+1))
done
fi

num=${#slist[@]}

if [[ $num = 1 ]]
then
# single node cluster
    hn0=${iplist[0]}
    hn1=${iplist[0]#}
    hn2=${iplist[0]#}
else
    hn0=${iplist[0]}
    hn1=${iplist[1]}
    hn2=${iplist[2]}
fi
if [[ $sName != "" ]]
then
printf "%s %s %s" "$hn0"
else
printf "%s %s %s" "$hn0" "$hn1" "$hn2" 
fi
