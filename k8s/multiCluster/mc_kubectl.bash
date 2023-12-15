#!/usr/bin/env bash

source init.conf

#export MDB_CENTRAL_C_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CENTRAL_REGION}_${MDB_CENTRAL_C}
#export MDB_CLUSTER_0_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_0_ZONE}_${MDB_CLUSTER_0}"
#export MDB_CLUSTER_1_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_1_ZONE}_${MDB_CLUSTER_1}"
#export MDB_CLUSTER_2_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_2_ZONE}_${MDB_CLUSTER_2}"

out=$( kubectl --context=$MDB_CENTRAL_C_CONTEXT -n $namespace $@ 2>&1 )
[[ $? == 0 ]] && printf "${out}\n\n"
out=$( kubectl --context=$MDB_CLUSTER_0_CONTEXT -n $namespace $@ 2>&1 )
[[ $? == 0 ]] && printf "${out}\n\n"
out=$( kubectl --context=$MDB_CLUSTER_1_CONTEXT -n $namespace $@ 2>&1 )
[[ $? == 0 ]] && printf "${out}\n\n"
out=$( kubectl --context=$MDB_CLUSTER_2_CONTEXT -n $namespace $@ 2>&1 )
[[ $? == 0 ]] && printf "${out}\n\n"
