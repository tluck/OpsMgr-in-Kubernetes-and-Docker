#!/bin/bash

source ~/k8s/init.conf
TAB=$'\t'

#if [[ ${1} == "" ]]
#then 
#    exit 1 -- need opsmanager service name
#else
name="${1-opsmanager}"
#fi

# get the OpsMgr URL and internal IP
opsMgrUrl=$(        kubectl get om                  -o json | jq .items[0].status.opsManager.url )
eval hostname=$(    kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval opsMgrExtIp=$( kubectl get svc/${name}-svc-ext -o json | jq .status.loadBalancer.ingress[0].ip ) 
eval port=$(        kubectl get svc/${name}-svc-ext -o json | jq .spec.ports[0].port )

http="http"
if [[ ${port} == "8443" ]]
then
    http="https"
fi

if [[ ${hostname} == "null" ]]
then
    opsMgrExtUrl=${http}://${opsMgrExtIp}:${port}
else
    opsMgrExtUrl=${http}://${hostname}:${port}
    if [[ "${hostname}" != "localhost" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        opsMgrExtIp=${list[3]}
    else
        opsMgrExtIp=127.0.0.1
    fi
fi

# get the internal IP
eval hostname=$( kubectl get svc/${name}-backup -o json | jq .status.loadBalancer.ingress[0].hostname ) 
eval queryableBackupIp=$( kubectl get svc/${name}-backup -o json | jq .status.loadBalancer.ingress[0].ip ) 

if [[ ${hostname} != "null" ]]
then
    if [[ "${hostname}" != "localhost" ]]
    then
        eval list=( $( nslookup ${hostname} | grep Address ) )
        queryableBackupIp=${list[3]}
    else
        queryableBackupIp=127.0.0.1
    fi
fi

# Update init.conf with OpsMgr info
cat init.conf | sed -e '/opsMgrUrl/d' -e '/opsMgrExt/d' -e '/queryableBackupIp/d'  > new
echo ""
echo  opsMgrUrl="$opsMgrUrl"           | tee -a new
echo  opsMgrExtUrl=\""$opsMgrExtUrl"\" | tee -a new
echo  ""
echo  opsMgrExtIp=\""$opsMgrExtIp"\"   | tee -a new
echo  queryableBackupIp=\""$queryableBackupIp"\"    | tee -a new
mv new init.conf

printf "\n%s\n\n" "*** Note: sudo may ask for your password" 
# put the internal name opsmanager-svc.mongodb.svc.cluster.local in /etc/hosts
grep "^[0-9].*opsmanager-svc.mongodb.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing /etc/hosts entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc.mongodb.svc.cluster.local.*)|${opsMgrExtIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding /etc/hosts entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" | sudo tee -a /etc/hosts
fi

# put the internal name opsmanager-svc for queriable backup /etc/hosts
grep "^[0-9].*opsmanager-svc " /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing /etc/hosts entry:"
    printf "%s\n" "${queryableBackupIp}${TAB}opsmanager-svc " 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc .*)|${queryableBackupIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding /etc/hosts entry:"
    printf "%s\n" "${queryableBackupIp}${TAB}opsmanager-svc " | sudo tee -a /etc/hosts
fi

# get the node info for creating custom clusters via agent automation
hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )

if [[ ${hostname} == "docker-desktop" ]]
then
hostname=(docker-desktop)
dnslist=(docker-desktop)
iplist=(127.0.0.1)
fi

names=( mongodb1 mongodb2 mongodb3 )
num=${#iplist[@]}
num=$(( $num-1 ))

printf "\n" 
for n in 0 1 2
do
  m=$n;  if [[ $m > $num ]]; then m=$num; fi;
  grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}" 
    sudo sed -E -i .bak -e "s|^[0-9].*${names[$n]}.*|${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}|" /etc/hosts
  else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${dnslist[$m]} ${hostname[$m]}" | sudo tee -a /etc/hosts
  fi

done
