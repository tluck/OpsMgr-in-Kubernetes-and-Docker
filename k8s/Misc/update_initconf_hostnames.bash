#!/bin/bash

source ~/k8s/init.conf
TAB=$'\t'

#if [[ ${1} == "" ]]
#then 
#    exit 1 -- need opsmanager service name
#else

name="${1:-opsmanager}"
#fi

# get the OpsMgr URL and internal IP
opsMgrUrl=$(        kubectl get om                  -o json | jq .items[0].status.opsManager.url )
eval hostname=$(    kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval opsMgrExtIp=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
eval port=$(        kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].port )
eval nodePort=$(    kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].nodePort )
eval portType=$(    kubectl get svc/${name}-svc-ext -o json | jq .spec.type )


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
    opsMgrExtUrl=${http}://${opsMgrExtIp}:${port}
else
    opsMgrExtUrl=${http}://${hostname}:${port}
    if [[ "${hostname}" != "localhost" && "${hostname}" != "" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        opsMgrExtIp=${list[3]}
    else
        opsMgrExtIp=127.0.0.1
    fi
fi

# Update init.conf with OpsMgr info
initconf=$( sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d' -e '/queryableBackupIp/d' init.conf )
printf "%s\n" "$initconf" > init.conf
echo ""
echo  opsMgrUrl="$opsMgrUrl"                        | tee -a init.conf
echo  opsMgrExtUrl=\""$opsMgrExtUrl"\"              | tee -a init.conf
echo  opsMgrExtIp=\""$opsMgrExtIp"\"                | tee -a init.conf
# echo  queryableBackupIp=\""$queryableBackupIp"\"    | tee -a init.conf

if [[ ${opsMgrExtIp} != "" ]]
then
printf "\n%s\n\n" "*** Note: sudo may ask for your password" 
# put the internal name opsmanager-svc.mongodb.svc.cluster.local in /etc/hosts
grep "^[0-9].*${name}-svc.mongodb.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.mongodb.svc.cluster.local ${name}-svc" 
    sudo sed -E -i .bak -e "s|^[0-9].*(${name}-svc.mongodb.svc.cluster.local.*)|${opsMgrExtIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n" "${opsMgrExtIp}${TAB}${name}-svc.mongodb.svc.cluster.local ${name}-svc" | sudo tee -a /etc/hosts
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
#     sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc$)|${queryableBackupIp}${TAB}\1|" /etc/hosts
# else
#     # add host entry
#     printf "%s" "Adding /etc/hosts entry: "
#     printf "%s\n" "${queryableBackupIp}${TAB}opsmanager-svc" | sudo tee -a /etc/hosts
# fi
# fi

# get the node info for creating an external cluster via agent automation
hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )

if [[ ${hostname} == "docker-desktop" ]]
then
    hostname=(docker-desktop)
    dnslist=(docker-desktop)
    iplist=(127.0.0.1)
fi

# add 3 nodes to the /etc/hosts
names=( mongodb1 mongodb2 mongodb3 mongos-0 )  
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
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}" 
    sudo sed -E -i .bak -e "s|^[0-9].*${names[$n]}.*|${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}|" /etc/hosts
  else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}" | sudo tee -a /etc/hosts
  fi
done
n=3
name=( $( kubectl get svc|grep svc-external ) )
name=${name[0]%%-*}
name1=${name}-mongos-0.mysharded-svc.mongodb.svc.cluster.local
name2=${name}-svc.mongodb.svc.cluster.local
  grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${name1} ${name2}" 
    sudo sed -E -i .bak -e "s|^[0-9].*${names[$n]}.*|${iplist[$m]}${TAB}${names[$n]} ${name1} ${name2}|" /etc/hosts
  else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${name1} ${name2}" | sudo tee -a /etc/hosts
  fi
