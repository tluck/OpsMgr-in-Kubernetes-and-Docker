#!/bin/bash

source init.conf
TAB=$'\t'

getOMname() {
name=$1
# get the OpsMgr URL and internal IP
opsMgrUrl=$(        kubectl get om/${name}          -o jsonpath={.status.opsManager.url} )
eval port=$(        kubectl get svc/${name}-svc-ext -o jsonpath={.spec.ports[0].port} )
eval targetPort=$(  kubectl get svc/${name}-svc-ext -o jsonpath={.spec.ports[0].targetPort} )
eval nodePort=$(    kubectl get svc/${name}-svc-ext -o jsonpath={.spec.ports[0].nodePort} )
eval serviceType=$( kubectl get svc/${name}-svc-ext -o jsonpath={.spec.type} )

if [[ $serviceType == "NodePort" ]]
then
    slist=( $(get_hns.bash -n "${name}" ) ) 
    hostname="${slist[0]%:*}"
    slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
    [[ ${slist[0]} == "" ]] && slist=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' ) )
    opsMgrExtIp=${slist[0]}
else
    eval hostname=$(    kubectl get svc/${name}-svc-ext -o jsonpath={.status.loadBalancer.ingress[0].hostname} ) 
    eval opsMgrExtIp=$( kubectl get svc/${name}-svc-ext -o jsonpath={.status.loadBalancer.ingress[0].ip} ) 
fi

http="http"
if [[ ${targetPort} == "8443" ]]
then
    http="https"
fi
if [[ ${serviceType} == "NodePort" ]]
then
    port=${nodePort}
fi

if [[ ${hostname} == "null" ]]
then
    opsMgrExtUrl1=${http}://${opsMgrExtIp}:${port}
else
    opsMgrExtUrl1=${http}://${hostname}:${port}
    opsMgrExtUrl2=${http}://${omExternalName}:${port}
    if [[ $opsMgrExtIp == "" ]]
    then
        eval list=( $(nslookup ${hostname} | grep Address ) )
        opsMgrExtIp=${list[3]}
    fi
    [[ "${hostname}" == "localhost" ]] && opsMgrExtIp=127.0.0.1
fi

# Update init.conf with OpsMgr info
initconf=$( sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d' -e '/queryableBackupIp/d' init.conf )
printf "%s\n" "$initconf" > init.conf
echo ""
echo  opsMgrUrl=\""$opsMgrUrl"\"                    | tee -a init.conf
echo  opsMgrExtUrl1=\""$opsMgrExtUrl1"\"            | tee -a init.conf
echo  opsMgrExtUrl2=\""$opsMgrExtUrl2"\"            | tee -a init.conf
echo  opsMgrExtIp=\""$opsMgrExtIp"\"                | tee -a init.conf

if [[ ${opsMgrExtIp} != "" ]]
then
printf "\n%s\n\n" "*** Note: sudo may ask for your password" 
# put the name and IP for opsmanager in /etc/hosts 
grep "^[0-9].*${name}-svc.${namespace}.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${omExternalName}" 
    sudo ${sed} -E -e "s|^[0-9].*(${name}-svc.*.svc.cluster.local.*)|${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${omExternalName}|" /etc/hosts 1>/dev/null
else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${omExternalName}" | sudo tee -a /etc/hosts
fi
fi
}

getRSname() {
name=$1
# get the node info for creating an external cluster via agent automation

svc=( $( kubectl get svc|grep "${name}-." 2>/dev/null ) )
if [[ $? != 0 ]] 
then
    printf "%s\n" "* * * Error - svc ${name}-0 not found" 
    return
fi

if [[ $serviceType == "NodePort" ]]
then
	nodename=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
	dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
	iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
else
	list=( $( get_hns.bash -n "${name}" ) )
        [[ $? != 0 ]] && return
        dnslist=( ${list[*]%:*} ) # strip off port
	n=0
	for h in ${dnslist[*]}
	do
	ip=( $( nslookup $h | grep Address ) )
        #iplist[$n]="${ip#*:}"  # strip off Address:
        iplist[$n]="${ip[3]}"
        nodename[$n]=""
	n=$((n+1))
	done
fi

if [[ ${nodename} == "docker-desktop" ]]
then
    nodename=(docker-desktop)
    dnslist=(docker-desktop)
    iplist=(127.0.0.1)
fi
 
if [[ ${nodename} == "minikube" || ${nodename} == "colima" ]]
then
    nodename=($nodename)
    dnslist=($nodename)
    iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' ) )
fi

# add 3 nodes to the /etc/hosts file
names=( mongodb1 mongodb2 mongodb3 )  

num=${#iplist[@]}
if [[ ${num} > 0 ]]
then
    num=$(( $num-1 ))
else
    return
fi

printf "\n" 
for n in 0 1 2
do
  m=$n;  if [[ $m > $num ]]; then m=$num; fi;
  grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${nodename[$m]}" 
    sudo ${sed} -E -e "s|^[0-9].*${names[$n]}.*|${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${nodename[$m]}|" /etc/hosts 
  else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${nodename[$m]}" | sudo tee -a /etc/hosts
  fi
done
}

getSHname() {
name=${1}
# sharded mongos
slist=( $( kubectl get svc|grep "${name}-mongos-.-svc-external" 2>/dev/null |awk '{print $1}') )
if [[ $? != 0 || ${#slist} == 0 ]]
then
    printf "%s\n" "* * * Error - svc ${name}-mongos-*-svc-external not found" 
    return
fi
n=0
for s in ${slist[*]}
do 
    slist[$n]=$( get_hns.bash -s "${s}" ) 
    n=$((n+1))
done

dnslist=( ${slist[*]%:*} ) # strip off port

n=0
unset iplist
for h in ${dnslist[*]}
do
    ip=( $( nslookup $h | grep Address ) )
    iplist[$n]=${ip[3]}  # strip off Address:
    nodename[$n]=""
    n=$((n+1))
done

num=${#slist[@]}
if [[ ${num} < 1 ]]
then
    return
fi

printf "\n" 
n=0
while [ $n -lt $num ]
do
  sname="${name}-mongos-${n}.${name}-svc.${namespace}.svc.cluster.local"
  m=$n;  if [[ $m > $num ]]; then m=$num; fi;
  if [[ "${iplist[$m]}" == "" || "${sname}" == "" ]] 
  then
    printf "skipping mongos %d\n" $n
  else
  grep "^[0-9].*${sname%%.*}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n"                                        "${iplist[$m]}${TAB}${sname%%.*} ${sname}"
    sudo ${sed} -E -e "s|^[0-9].*${sname%%.*}.*|${iplist[$m]}${TAB}${sname%%.*} ${sname}|" /etc/hosts 
  else
    # add host entry
    printf "%s" "Adding    /etc/hosts entry: "
    printf "%s\n"                                      "${iplist[$m]}${TAB}${sname%%.*} ${sname}" | sudo tee -a /etc/hosts
  fi
  fi
  n=$((n+1))
done
}

# argument if set to 1 will skip creating new certs for OM and the App DB
while getopts 'o:r:s:h' opt
do
  case "$opt" in
    o)   om="$OPTARG" ;;
    r)   rs="$OPTARG" ;;
    s)   sh="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-o name] [-r name] [-s name]"
      echo "     use -o opsmanger"
      echo "     use -r a ReplicSet Cluster Name"
      echo "     use -r a Sharded Cluster Name"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

omName="${om:-opsmanager}"
rsName=$( printf "${rs}"| tr '[:upper:]' '[:lower:]' )
shName=$( printf "${sh}"| tr '[:upper:]' '[:lower:]' )

[[ "${omName}" != "" ]] && getOMname "$omName"
[[ "${rsName}" != "" ]] && getRSname "$rsName"
[[ "${shName}" != "" ]] && getSHname "$shName"

printf "\n" 

