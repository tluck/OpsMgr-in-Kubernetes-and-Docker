#!/bin/bash

name="${1:-myreplicaset}"

source init.conf

horizon=$( kubectl get svc/${name}-0 -o jsonpath='{.spec.type}' )
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

#cs="mongodb://${dbadmin}:${dbpassword}@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?replicaSet=${name}&authSource=admin"
ics=$( kubectl get secret ${name}-dbadmin-${name}-admin -o jsonpath="{.data['connectionString\.standard']}" | base64 --decode ) 
ecs=$( printf $ics | sed -e "s?@.*/?@${hn0}:${np0},${hn1}:${np1},${hn2}:${np2}/?" )

tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.authentication}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"\"enabled\":true"* || "${tls}" == *"prefix"* ]]
then
    #kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/ca.pem > ca.pem
    #kubectl exec ${name}-0 -i -t -- cat /mongodb-automation/server.pem > server.pem
    ##kubectl get secret mdb-${name}-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > server.pem
    ##kubectl get secret mdb-${name}-cert -o jsonpath="{.data['tls\.key']}" | base64 --decode >> server.pem
    test -e certs/ca.pem      || kubectl get configmap ca-pem -o jsonpath="{.data['ca-pem']}" > certs/ca.pem
    test -e certs/${name}.pem || kubectl get secret mdb-${name}-cert-pem -o jsonpath="{.data.*}" | base64 --decode > certs/${name}.pem
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile certs/ca.pem --sslPEMKeyFile certs/${name}.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile certs/ca.pem --tlsCertificateKeyFile certs/${name}.pem "
        ssltls_enabled="&tls=true"
    fi
fi

fcs=\'${ecs}${ssltls_enabled}\'
printf "%s\n" "${fcs} ${ssltls_options}"
#eval "mongo ${fcs} ${ssltls_options}"

