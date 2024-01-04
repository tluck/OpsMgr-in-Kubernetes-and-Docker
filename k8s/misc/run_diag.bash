# Gathering data from a Multi-Cluster environment
source init.conf

export MDB_CENTRAL_C_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CENTRAL_REGION}_${MDB_CENTRAL_C}"
export MDB_CLUSTER_0_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_0_ZONE}_${MDB_CLUSTER_0}"
export MDB_CLUSTER_1_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_1_ZONE}_${MDB_CLUSTER_1}"
export MDB_CLUSTER_2_CONTEXT="gke_${MDB_GKE_PROJECT}_${MDB_CLUSTER_2_ZONE}_${MDB_CLUSTER_2}"

export CENTRAL_CLUSTER="$MDB_CENTRAL_C_CONTEXT"
export MEMBER_CLUSTERS="$MDB_CLUSTER_0_CONTEXT $MDB_CLUSTER_1_CONTEXT $MDB_CLUSTER_2_CONTEXT"
#mdb_operator_diagnostic_data.sh mongodb multi-replica-set mdboperator enterprise-operator
rm -rf log* *.tar.gz
./mdb_operator_diagnostic_data.sh  mongodb mymulticlusterproject2-myreplicaset mongodb enterprise-operator

