#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

source init.conf

# Optinal - Create the metrics server
#kubectl apply -f /opt/Source/metrics-server/components.yaml 

# Create the namespace and context
kubectl create namespace mongodb
kubectl config set-context $(kubectl config current-context) --namespace=mongodb

# Deploy the MongoDB Enterprise Operator
kubectl apply -f crds.yaml
kubectl apply -f mongodb-enterprise.yaml

# Deploy simple SMTP forwarder 
mail/deploy_SMTP.bash
