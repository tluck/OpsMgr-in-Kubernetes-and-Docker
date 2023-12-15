#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

name=${1:-myproject1-myreplicaset}
shift
dnsHorizon=( $@ )

#source init.conf

# use wildcard vs individual certs now
#"$PWD/gen_cert.bash" "mdb-${name}-cert" "*.${name}-svc.${namespace}.svc.${clusterDomain}" ${dnsHorizon[*]}

# members=$( kubectl get mdb ${name} -o json|jq .spec.members )
# env vars provide externalDomain (for a cluster) and clusterDomain (k8s cluster domain)
members=3 # hard coded in template

n=0
if [[ ${externalDomain} == "" ]]
then

if [[ $multiCluster == true ]]
then
#myproject1-myreplicaset-0-0.myproject1-myreplicaset-0-svc.mongodb.svc.cluster.local
    names[0]="${name}-0-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[1]="${name}-0-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[2]="${name}-0-2-svc.${namespace}.svc.${multiClusterDomain}"
    names[3]="${name}-1-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[4]="${name}-1-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[5]="${name}-1-2-svc.${namespace}.svc.${multiClusterDomain}"
    names[6]="${name}-2-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[7]="${name}-2-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[8]="${name}-2-2-svc.${namespace}.svc.${multiClusterDomain}"

    names[9]="${name}-0-0.${name}-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[10]="${name}-0-1.${name}-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[11]="${name}-0-2.${name}-0-svc.${namespace}.svc.${multiClusterDomain}"
    names[12]="${name}-1-0.${name}-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[13]="${name}-1-1.${name}-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[14]="${name}-1-2.${name}-1-svc.${namespace}.svc.${multiClusterDomain}"
    names[15]="${name}-2-0.${name}-2-svc.${namespace}.svc.${multiClusterDomain}"
    names[16]="${name}-2-1.${name}-2-svc.${namespace}.svc.${multiClusterDomain}"
    names[17]="${name}-2-2.${name}-2-svc.${namespace}.svc.${multiClusterDomain}"
else

while [ $n -lt $members ]
do
    names[$n]="${name}-${n}.${name}-svc.${namespace}.svc.${clusterDomain}"
    n=$((n+1))
done
fi

else
# external Domain
if [[ $multiCluster == true ]]
then
    # myproject2-myreplicaset-0-0.clusterX.mdb.com
    names[0]="${name}-0-0.${MDB_CLUSTER_0}.${externalDomain}"
    names[1]="${name}-0-1.${MDB_CLUSTER_0}.${externalDomain}"
    names[2]="${name}-0-2.${MDB_CLUSTER_0}.${externalDomain}"
    names[3]="${name}-1-0.${MDB_CLUSTER_1}.${externalDomain}"
    names[4]="${name}-1-1.${MDB_CLUSTER_1}.${externalDomain}"
    names[5]="${name}-1-2.${MDB_CLUSTER_1}.${externalDomain}"
    names[6]="${name}-2-0.${MDB_CLUSTER_2}.${externalDomain}"
    names[7]="${name}-2-1.${MDB_CLUSTER_2}.${externalDomain}"
    names[8]="${name}-2-2.${MDB_CLUSTER_2}.${externalDomain}"

else
while [ $n -lt $members ]
do
    names[$n]="${name}-${n}.${externalDomain}"
    n=$((n+1))
done
fi

fi

"$PWD/gen_cert.bash" "mdb-${name}-cert" ${names[*]} ${dnsHorizon[*]}
