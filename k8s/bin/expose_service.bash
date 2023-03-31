#!/bin/bash

fn="$1"
shift;
if [[ "${fn}" == "" ]]
then
    printf "%s\n" "Exit - need yaml file argument"
    exit 1
fi

s=( $( grep " name" "${fn}") )
name="${s[1]}"

source init.conf
PATH=.:bin:$PATH

expose="svc_expose_template.yaml"
if [[ "${serviceType}" == "LoadBalancer" ]]
then
    cat ${expose} | sed -e "s/NAME/$name/" -e "s/PORTTYPE/LoadBalancer/g" > svc_lb_${name}.yaml
    kubectl apply -f svc_lb_${name}.yaml
else
    cat ${expose} | sed -e "s/NAME/$name/" -e "s/PORTTYPE/NodePort/g" > svc_np_${name}.yaml
    kubectl apply -f svc_np_${name}.yaml
fi

n=0
while [ $n -lt 12 ]
do
    kubectl get svc ${name}-0 ${name}-1 ${name}-2 |grep pending 2>&1 > /dev/null
    if [[ $? = 1 ]]
    then
        kubectl get svc ${name}-0 ${name}-1 ${name}-2 
        break
    fi
    sleep 15
    n=$((n+1))
done

hn=( $( get_hns.bash -n "${name}" ) )
if [[ $? != 0 ]]
then
    printf "\n%s\n" "* * * - Error cannot determine the hostnames for splitHorizon"
    exit 1
fi

cat "$fn" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
echo "  connectivity:"                     | tee -a new
echo "    replicaSetHorizons:"             | tee -a new
echo "      -" \"horizon-1\": \"${hn[0]}\" | tee -a new
echo "      -" \"horizon-1\": \"${hn[1]}\" | tee -a new
echo "      -" \"horizon-1\": \"${hn[2]}\" | tee -a new
mv new "$fn"

#echo
printf "${hn[*]%:*}"
