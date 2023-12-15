#!/usr/bin/env bash

source init.conf

kubectl label \
  --context=$MDB_CLUSTER_0_CONTEXT \
  namespace mongodb \
  istio-injection=enabled

kubectl label \
  --context=$MDB_CLUSTER_1_CONTEXT \
  namespace mongodb \
  istio-injection=enabled

kubectl label \
  --context=$MDB_CLUSTER_2_CONTEXT \
  namespace mongodb \
  istio-injection=enabled
