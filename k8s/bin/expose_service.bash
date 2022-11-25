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
PATH=.:bin:$PATH

# remove any old services
if [[ $clean = 1 ]]
then
    printf "%s\n" "Deleting existing svc ${name}-0 ${name}-1 ${name}-2"
    kubectl delete svc ${name}-0 ${name}-1 ${name}-2 > /dev/null 2>&1
fi
#create nodeport service
if [[ "${serviceType}" == "LoadBalancer" ]]
then
    cat svc_expose_template.yaml| sed -e "s/NAME/$name/" -e "s/PORTTYPE/LoadBalancer/g" > svc_lb_${name}.yaml
    kubectl apply -f svc_lb_${name}.yaml
else
    cat svc_expose_template.yaml| sed -e "s/NAME/$name/" -e "s/PORTTYPE/NodePort/g" > svc_np_${name}.yaml
    kubectl apply -f svc_np_${name}.yaml
fi

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

hn=( $( get_hns.bash -n "${name}" -t "${serviceType}" ) )

cat "$fn" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
echo "  connectivity:"                        | tee -a new
echo "    replicaSetHorizons:"                | tee -a new
echo "      -" \"horizon-1\": \"${hn[0]}\" | tee -a new
echo "      -" \"horizon-1\": \"${hn[1]}\" | tee -a new
echo "      -" \"horizon-1\": \"${hn[2]}\" | tee -a new
mv new "$fn"

#initconf=$( sed -e "/${name//-/}_URI/d" init.conf )
#printf "%s\n" "${initconf}" > init.conf
#echo 
#echo "Adding the connection string variable to init.conf:"
#echo "${name//-/}_URI=\"mongodb://${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name} -u \$dbuser -p \$dbpassword --authenticationDatabase admin \" " | tee -a init.conf
#echo "${name//-/}_URI=\"mongodb://${dbuser}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authMechanism=SCRAM-SHA-256&authSource=admin\"" | tee -a init.conf
#echo "${name//-/}_URI=\"mongodb://${dbuser}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin\"" | tee -a init.conf
#echo
printf "${hn[*]%:*}" > dnsHorizon
