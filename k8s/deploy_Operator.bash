#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

# Optinal - Create the metrics server
#kubectl apply -f /opt/Source/metrics-server/components.yaml 

# Create the namespace and context
kubectl create namespace ${namespace}
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}

# Deploy the MongoDB Enterprise Operator
kubectl apply -f crds.yaml
if [[ "${clusterType}" == "openshift" ]]
then
    cat mongodb-enterprise-openshift.yaml | sed \
    -e "s/namespace: mongodb/namespace: $namespace/"  > "mongodb-operator.yaml"
else
    cat mongodb-enterprise.yaml | sed \
    -e "s/namespace: mongodb/namespace: $namespace/"  > "mongodb-operator.yaml"
fi
kubectl apply -f mongodb-operator.yaml
