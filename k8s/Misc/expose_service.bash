#!/bin/bash

fn="$1"
shift;
clean="$1"
if [[ "${fn}" == "" ]]
then
    printf "%s\n" "Exit - need yaml file argument"
    exit 1
fi

s=( $( grep " name" "${fn}") )
name="${s[1]}"

source init.conf

# remove any old services
if [[ $clean = 1 ]]
then
    printf "%s\n" "Deleting existing svc ${name}-0 ${name}-1 ${name}-2"
    kubectl delete svc ${name}-0 ${name}-1 ${name}-2 > /dev/null 2>&1
fi
#create nodeport service
if [[ "${horizon}" == "LoadBalancer" ]]
then
    cat svc_expose_template.yaml| sed -e "s/NAME/$name/" -e "s/PORTTYPE/LoadBalancer/g" > svc_lb_${name}.yaml
    kubectl apply -f svc_lb_${name}.yaml
else
    cat svc_expose_template.yaml| sed -e "s/NAME/$name/" -e "s/PORTTYPE/NodePort/g" > svc_np_${name}.yaml
    kubectl apply -f svc_np_${name}.yaml
fi

# kubectl expose pod ${name}-0 --type="LoadBalancer" --port 27017 -n mongodb
# kubectl expose pod ${name}-1 --type="LoadBalancer" --port 27017 -n mongodb
# kubectl expose pod ${name}-2 --type="LoadBalancer" --port 27017 -n mongodb

while true
do
    kubectl get svc ${name}-0 ${name}-1 ${name}-2 |grep pending
    if [[ $? = 1 ]]
    then
        kubectl get svc ${name}-0 ${name}-1 ${name}-2 
        break
    fi
    printf "%s\n" "Sleeping 15 seconds to allow IP/Hostnames to be created"
    sleep 15
done

if [[ "$horizon" == "LoadBalancer" ]]
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
    np0=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.ports[0].nodePort}' )
    np1=$( kubectl get svc/${name}-1 -o jsonpath='{.spec.ports[0].nodePort}' )
    np2=$( kubectl get svc/${name}-2 -o jsonpath='{.spec.ports[0].nodePort}' )

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

fi

num=${#slist[@]}

if [[ $num = 0 ]]
then
    printf "%s\n" -- "Can't create split horizon map - exiting"
    exit 1
fi

if [[ $num = 1 ]]
then
# single node cluster
    hn0=${slist[0]}
    hn1=${slist[0]}
    hn2=${slist[0]}
else
    hn0=${slist[0]}
    hn1=${slist[1]}
    hn2=${slist[2]}
fi

cat "$fn" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
echo "  connectivity:"                        | tee -a new
echo "    replicaSetHorizons:"                | tee -a new
echo "      -" \"horizon-1\": \"${hn0}:$np0\" | tee -a new
echo "      -" \"horizon-1\": \"${hn1}:$np1\" | tee -a new
echo "      -" \"horizon-1\": \"${hn2}:$np2\" | tee -a new
mv new "$fn"

initconf=$( sed -e "/${name//-/}_URI/d" init.conf )
printf "%s\n" "${initconf}" > init.conf
echo 
echo "Adding the connection string variable to init.conf:"
#echo "${name//-/}_URI=\"mongodb://${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name} -u \$dbadmin -p \$dbpassword --authenticationDatabase admin \" " | tee -a init.conf
#echo "${name//-/}_URI=\"mongodb://${dbadmin}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authMechanism=SCRAM-SHA-256&authSource=admin\"" | tee -a init.conf
echo "${name//-/}_URI=\"mongodb://${dbadmin}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin\"" | tee -a init.conf
echo
printf "%s %s %s" "$hn0" "$hn1" "$hn2" > dnsHorizon
