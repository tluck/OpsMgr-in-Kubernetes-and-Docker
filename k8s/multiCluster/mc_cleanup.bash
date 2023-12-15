#!/usr/bin/env bash

source init.conf

contexts=$(kubectl config get-contexts -o name | grep gke | sort -r)

for context in $contexts
do
    kubectl --context=$context delete namespace $namespace
done
