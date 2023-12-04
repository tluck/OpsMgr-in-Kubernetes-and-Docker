#!/bin/bash

source init.conf

d=$( dirname "$0" )
cd "${d}"
name=${1:-opsmanager}

#def_token=( $( kubectl get secrets | grep default-token ) )
#kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt
#kubectl get secret -n default -o jsonpath="{.items[?(@.type==\"kubernetes.io/service-account-token\")].data['ca\.crt']}" | base64 --decode > ca.crt

cert="${name}-svc"

# certs for the proxy server for queryable backup
if [[ ! -e queryable-backup.pem ]]
then
    "$PWD/gen_cert.bash" ${cert} ${name}-svc ${name}-svc.${namespace}.svc.${clusterDomain} ${name}-backup-daemon-0 ${name}-backup-daemon-0.${name}-backup-daemon-svc.${namespace}.svc.${clusterDomain} 
    kubectl apply -f "$PWD/certs_${cert}.yaml"
    while true
    do
    sleep 5
    kubectl get secret/"${cert}" > /dev/null 2>&1
    [[ $? == 0 ]] && break
    done
    kubectl get secret "${cert}" -o jsonpath="{.data.tls\.crt}"|base64 -d > "${cert}.crt"
    kubectl get secret "${cert}" -o jsonpath="{.data.tls\.key}"|base64 -d > "${cert}.key"
    cat "${cert}.key" "${cert}.crt" ca.key ca.crt > queryable-backup.pem
    rm "${cert}.key" "${cert}.crt" 
    [[ -e "queryable-backup.pem" ]] && printf "%s\n" "Made queryable-backup.pem" 
fi

# OM
# makes opmanager-svc.pem
"$PWD/gen_cert.bash" "${cert}" "${name}-svc" "${name}-svc.${namespace}.svc.${clusterDomain}" "${omExternalName}"
kubectl apply -f "$PWD/certs_${cert}.yaml"
    while true
    do
    sleep 5
    kubectl get secret/"${cert}" > /dev/null 2>&1
    [[ $? == 0 ]] && break
    done
kubectl get secret "${cert}" -o jsonpath="{.data.tls\.crt}"|base64 -d > "${cert}.crt"
kubectl get secret "${cert}" -o jsonpath="{.data.tls\.key}"|base64 -d > "${cert}.key"
cat "${cert}.key" "${cert}.crt" > "${cert}.pem"
[[ -e "${cert}.pem" ]] && printf "%s\n" "Made ${cert}.pem"

# appdb
# use prefix om
#"$PWD/gen_cert.bash" ${name}-db-cert "*.${name}-db-svc.${namespace}.svc.${clusterDomain}" 

members=3 # hard coded in template
n=0
while [ $n -lt $members ]
do
    names[$n]="${name}-db-${n}.${name}-db-svc.${namespace}.svc.${clusterDomain}"
    n=$((n+1))
done

"$PWD/gen_cert.bash" "om-${name}-db-cert" ${names[*]}
