#!/bin/bash

if [[ $1 == "" ]]
then
    printf "%s\n" "Exit - need yaml file argument"
    exit 1
fi

# remove any old services
kubectl delete svc my-replica-set-0 > /dev/null 2>&1
kubectl delete svc my-replica-set-1 > /dev/null 2>&1
kubectl delete svc my-replica-set-2 > /dev/null 2>&1

# create nodeport service
kubectl expose pod my-replica-set-0 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-1 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-2 --type="NodePort" --port 27017 -n mongodb

np0=( $(kubectl get svc/my-replica-set-0 -o jsonpath='{.spec.ports[0].nodePort}') )
np1=( $(kubectl get svc/my-replica-set-1 -o jsonpath='{.spec.ports[0].nodePort}') )
np2=( $(kubectl get svc/my-replica-set-2 -o jsonpath='{.spec.ports[0].nodePort}') )

hn0=$(kubectl get svc/my-replica-set-0 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
hn1=$(kubectl get svc/my-replica-set-1 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
hn2=$(kubectl get svc/my-replica-set-2 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

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
if [[ $hn0 == "" ]] 
then
    hn0=${dnlist[0]}
    hn1=${dnlist[1]}
    hn2=${dnlist[2]}
fi

num=${#dnlist[@]}

cat $1 | sed -e '/nodeport/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
echo "  connectivity:"                       | tee -a new
echo "    replicaSetHorizons:"               | tee -a new
echo "      -" \"nodeport\": \"${hn0}:$np0\" | tee -a new
echo "      -" \"nodeport\": \"${hn1}:$np1\" | tee -a new
echo "      -" \"nodeport\": \"${hn2}:$np2\" | tee -a new
mv new $1

cat init.conf | sed -e '/myReplicaSetConnect/d' > new
echo
echo "myReplicaSetConnect=\"mongodb://${hn0}:$np0,${hn1}:$np1,${hn2}:$np2/?replicaSet=my-replica-set --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem -u \$dbadmin -p \$dbpassword\"" | tee -a new
echo
mv new init.conf
