#!/bin/bash

source ~/k8s/init.conf
TAB=$'\t'

#if [[ ${1} == "" ]]
#then 
#    exit 1 -- need opsmanager service name
#else

name="${1:-opsmanager}"
replicasetName="${2}"
shardingName="${3}"
#fi

# get the OpsMgr URL and internal IP
opsMgrUrl=$(        kubectl get om/${name}          -o jsonpath={.status.opsManager.url} )
eval hostname=$(    kubectl get svc/${name}-svc-ext -o jsonpath={.status.loadBalancer.ingress[0].hostname} ) 
eval opsMgrExtIp=$( kubectl get svc/${name}-svc-ext -o jsonpath={.status.loadBalancer.ingress[0].ip} ) 
eval port=$(        kubectl get svc/${name}-svc-ext -o jsonpath={.spec.ports[0].port} )
eval nodePort=$(    kubectl get svc/${name}-svc-ext -o jsonpath={.spec.ports[0].nodePort} )
eval portType=$(    kubectl get svc/${name}-svc-ext -o jsonpath={.spec.type} )


http="http"
if [[ ${port} == "8443" ]]
then
    http="https"
fi
if [[ ${portType} == "NodePort" ]]
then
    port=${nodePort}
fi

if [[ ${hostname} == "null" ]]
then
    opsMgrExtUrl1=${http}://${opsMgrExtIp}:${port}
else
    opsMgrExtUrl1=${http}://${hostname}:${port}
    opsMgrExtUrl2=${http}://${om_ext}:${port}
    if [[ "${hostname}" != "localhost" && "${hostname}" != "" ]]
    then
        eval list=( $(nslookup ${hostname} | grep Address ) )
        opsMgrExtIp=${list[3]}
    else
        opsMgrExtIp=127.0.0.1
    fi
fi

# Update init.conf with OpsMgr info
initconf=$( sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d' -e '/queryableBackupIp/d' init.conf )
printf "%s\n" "$initconf" > init.conf
echo ""
echo  opsMgrUrl=\""$opsMgrUrl"\"                    | tee -a init.conf
echo  opsMgrExtUrl1=\""$opsMgrExtUrl1"\"              | tee -a init.conf
echo  opsMgrExtUrl2=\""$opsMgrExtUrl2"\"            | tee -a init.conf
echo  opsMgrExtIp=\""$opsMgrExtIp"\"                | tee -a init.conf
# echo  queryableBackupIp=\""$queryableBackupIp"\"    | tee -a init.conf

if [[ ${opsMgrExtIp} != "" ]]
then
printf "\n%s\n\n" "*** Note: sudo may ask for your password" 
# put the internal name opsmanager-svc.${namespace}.svc.cluster.local in /etc/hosts
grep "^[0-9].*${name}-svc.${namespace}.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${om_ext}" 
    sudo ${sed} -E -e "s|^[0-9].*(${name}-svc.*.svc.cluster.local.*)|${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${om_ext}|" /etc/hosts 1>/dev/null
else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.${namespace}.svc.cluster.local ${name}-svc ${om_ext}" | sudo tee -a /etc/hosts
fi
fi

# # get the internal IP (Hack for access to backup proxy)
# eval hostname=$(          kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
# eval queryableBackupIp=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 

# if [[ ${hostname} != "null" ]]
# then
#     if [[ "${hostname}" != "localhost" && "${hostname}" != "" ]]
#     then
#         eval list=( $( nslookup ${hostname} | grep Address ) )
#         queryableBackupIp=${list[3]}
#     else
#         queryableBackupIp=127.0.0.1
#     fi
# fi

# if [[ ${queryableBackupIp} != "" ]]
# then
# # put the internal name opsmanager-svc for queriable backup /etc/hosts
# grep "^[0-9].*opsmanager-svc$" /etc/hosts > /dev/null 2>&1
# if [[ $? == 0 ]]
# then
#     # replace host entry
#     printf "%s" "Replacing /etc/hosts entry: "
#     printf "%s\n" "${queryableBackupIp}${TAB}opsmanager-svc" 
#     sudo ${sed} -E -e "s|^[0-9].*(opsmanager-svc$)|${queryableBackupIp}${TAB}\1|" /etc/hosts
# else
#     # add host entry
#     printf "%s" "Adding /etc/hosts entry: "
#     printf "%s\n" "${queryableBackupIp}${TAB}opsmanager-svc" | sudo tee -a /etc/hosts
# fi
# fi

if [[ $replicasetName != "" ]]
then
# get the node info for creating an external cluster via agent automation
if [[ $serviceType == "NodePort" ]]
then
	nodename=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
	dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
	iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
else
	list=( $( get_hns.bash ) )
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

# add 3 nodes to the /etc/hosts file
names=( mongodb1 mongodb2 mongodb3 )  

num=${#iplist[@]}
if [[ ${num} > 0 ]]
then
    num=$(( $num-1 ))
else
    exit
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

fi

if [[ $shardingName != "" ]]
then
# sharding mongos
name=( $( kubectl get svc|grep -v "${name}" | grep svc-external ) )
name=${name[0]%%-svc*}
list=( $( get_hns.bash -n ${name} ) )
dnslist=( ${list[*]%:*} ) # strip off port

n=0
unset iplist
for h in ${dnslist[*]}
do
    ip=( $( nslookup $h | grep Address ) )
    iplist[$n]=${ip[3]}  # strip off Address:
    nodename[$n]=""
    n=$((n+1))
done
num=${#iplist[@]}
if [[ ${num} > 0 ]]
then
    num=$(( $num-1 ))
else
    exit
fi

if [[ $? == 0 ]]
then
    name=${name[0]%%-svc*}
    snames[0]="${name}-mongos-0.${name}-svc.${namespace}.svc.cluster.local"
    snames[1]="${name}-mongos-1.${name}-svc.${namespace}.svc.cluster.local"
    snames[2]="${name}-mongos-2.${name}-svc.${namespace}.svc.cluster.local"
fi

printf "\n" 
for n in 0 1 2
do
  m=$n;  if [[ $m > $num ]]; then m=$num; fi;
  if [[ "${iplist[$m]}" == "" || "${snames[$n]}" == "" ]] 
  then
    printf "skipping mongos %d\n" $n
  else
  grep "^[0-9].*${snames[$n]%%.*}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n"                                        "${iplist[$m]}${TAB}${snames[$n]%%.*} ${snames[$n]}"
    sudo ${sed} -E -e "s|^[0-9].*${snames[$n]%%.*}.*|${iplist[$m]}${TAB}${snames[$n]%%.*} ${snames[$n]}|" /etc/hosts 
  else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n"                                      "${iplist[$m]}${TAB}${snames[$n]%%.*} ${snames[$n]}" | sudo tee -a /etc/hosts
  fi
  fi
done
fi
printf "\n" 

