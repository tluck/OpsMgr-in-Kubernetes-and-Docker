#!/bin/bash

source ~/k8s/init.conf

TAB=$'\t'

grep "^[0-9].*opsmanager-svc.mongodb.svc.cluster.local" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" 
    sudo sed -E -i .bak -e "s|^[0-9].*(opsmanager-svc.mongodb.svc.cluster.local)|${opsMgrExtIp}${TAB}\1|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n" "${opsMgrExtIp}${TAB}opsmanager-svc.mongodb.svc.cluster.local" | sudo tee -a /etc/hosts
fi

hostname=( $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="Hostname")].address}') )
dnslist=(  $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )
iplist=(   $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}' ) )
names=( mongodb1 mongodb2 mongodb3 )

if [[ ${hostname} == "docker-desktop" ]]
then
hostname=(docker-desktop docker-desktop docker-desktop)
dnslist=(docker-desktop docker-desktop docker-desktop)
iplist=(127.0.0.1 127.0.0.1 127.0.0.1)
fi

for n in 0 1 2
do

grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
if [[ $? == 0 ]]
then
    # replace host entry
    printf "%s\n" "Replacing host entry:"
    printf "%s\n"                                   "${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}" 
    sudo sed -E -i .bak -e "s|^[0-9].*${names[$n]}.*|${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}|" /etc/hosts
else
    # add host entry
    printf "%s\n" "Adding host entry:"
    printf "%s\n"                                   "${iplist[$n]}${TAB}${names[$n]} ${dnslist[$n]} ${hostname[$n]}" | sudo tee -a /etc/hosts
fi

done
