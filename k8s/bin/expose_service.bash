#!/bin/bash

while getopts 'n:gh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    g) makeCerts="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myproject1-myreplicaset}
mdb="mdb_${name}.yaml"
makeCerts=${makeCerts:-true}

source init.conf
[[ ${demo} ]] && serviceType="NodePort"
#PATH=.:bin:$PATH

# use externalService managed by the operator now
# expose="svc_expose_template.yaml"
# if [[ "${serviceType}" == "LoadBalancer" ]]
# then
#     cat ${expose} | sed -e "s/NAME/$name/" -e "s/SERVICETYPE/LoadBalancer/g" > svc_lb_${name}.yaml
#     kubectl apply -f svc_lb_${name}.yaml
# else
#     cat ${expose} | sed -e "s/NAME/$name/" -e "s/SERVICETYPE/NodePort/g" > svc_np_${name}.yaml
#     kubectl apply -f svc_np_${name}.yaml
# fi

n=0
max=10
while [ $n -lt $max ]
do
    out=$( kubectl get svc | grep "${name}.*external" ) 
    if [[ $out != "" && $? == 0 ]]
    then
        #printf "${out}\n"
        #kubectl get svc -o name | grep "${name}.*external" 
        #[[ $? == 1 ]] && exit 1
        break
    fi
    sleep 5
    n=$((n+1))
done
[[ $n == $max ]] && exit 1

n=0
max=30
while [ $n -lt $max ]
do
    out=$( kubectl get svc | grep "${name}.*external.*pending" ) 
    if [[ $? == 1 ]]
    then
        kubectl get $( kubectl get svc -o name | grep "${name}.*external" ) 
        [[ $? == 1 ]] && exit 1
        break
    fi
    sleep 5
    n=$((n+1))
done

[[ ${externalDomain} ]] && exit

hnwp=( $( get_hns.bash -n "${name}" ) )
if [[ $? != 0 ]]
then
    printf "\n%s\n" "* * * Error - cannot determine the external hostnames for splitHorizon or externalDomain"
    exit 1
fi

    cat "$mdb" | sed -e '/horizon/d' -e '/connectivity:/d' -e '/replicaSetHorizons:/d' > new
    echo "  connectivity:"                     >> new
    echo "    replicaSetHorizons:"             >> new
    echo "      -" \"horizon-1\": \"${hnwp[0]}\" >> new
    echo "      -" \"horizon-1\": \"${hnwp[1]}\" >> new
    echo "      -" \"horizon-1\": \"${hnwp[2]}\" >> new
    mv new "$mdb"
hn=( $( printf "${hnwp[*]%:*}" ) )
# now remake the certs - and re-apply
if [[ ${makeCerts} == true && ${#hn[@]} != 0 ]] 
then
    "${PWD}/certs/make_cluster_certs.bash" "${name}" ${hn[@]}
    kubectl apply -f "${PWD}/certs/certs_mdb-${name}-cert.yaml"
fi
exit
