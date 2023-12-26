#!/bin/bash

source init.conf

# the actual names for clusters and zones are set in init.conf
domain="${clusterDomain:-mdb.com}"
nodesPerRegion="2" # 1 = 3 total nodes, 2 = 6 total nodes (2 per zone)x(3 zones)
nodesPerZone="3" # 3 total nodes per zone
expire="2023-12-31"
centralType="e2-standard-8"
memberType="e2-standard-4"

# e2-standard-2 2 core x  8 GB
# e2-standard-4 4 core x 16 GB
# e2-standard-8 8 core x 32 GB

# Note: these next two variables are variable names
cluster="MDB_CENTRAL_C"
gkeRegion=MDB_CENTRAL_REGION
set -x
gcloud container clusters create ${!cluster} --region="${!gkeRegion}" \
    --cluster-dns="clouddns" \
    --cluster-dns-scope="vpc" \
    --cluster-dns-domain="${domain}" \
  --num-nodes=${nodesPerRegion} \
  --machine-type "${centralType}" \
  --cluster-version="1.27" \
  --labels="expire-on=${expire},owner=thomas_luckenbach,purpose=opportunity,noreap=true" \
  --node-labels="expire-on=${expire},owner=thomas_luckenbach,purpose=opportunity,noreap=true"
set +x
gcloud container clusters get-credentials ${!cluster} --region="${!gkeRegion}"

# 3 member clusters for the ISTIO Mesh
for n in 0 1 2 
do
  cluster=MDB_CLUSTER_${n}
  gkeZone=MDB_CLUSTER_${n}_ZONE
  set -x
    gcloud container clusters create ${!cluster} --zone="${!gkeZone}" \
    --num-nodes=${nodesPerZone} \
    --machine-type "${memberType}" \
    --cluster-version="1.27" \
    --labels="expire-on=${expire},owner=thomas_luckenbach,purpose=opportunity,noreap=true" \
    --node-labels="expire-on=${expire},owner=thomas_luckenbach,purpose=opportunity,noreap=true"
  set +x
  gcloud container clusters get-credentials ${!cluster} --zone=${!gkeZone}
done

# make the ISTIO Mesh
_install_istio_separate_network.sh 
