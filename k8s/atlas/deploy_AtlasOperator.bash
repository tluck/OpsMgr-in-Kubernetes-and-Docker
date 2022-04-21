#!/bin/bash

source init.conf

# deploy the operator
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy Operator ..."
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-atlas-kubernetes/main/deploy/all-in-one.yaml

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Set K8S Namespace ..."
## kubectl create namespace ${namespace} > /dev/null 2>&1
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}

# 1. Create an Atlas API Key Secret
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create Secrets for Org and API key ..."

kubectl delete secret mongodb-atlas-operator-api-key > /dev/null 2>&1
kubectl create secret generic mongodb-atlas-operator-api-key \
         --from-literal="orgId=${orgId}" \
         --from-literal="publicApiKey=${publicApiKey}" \
         --from-literal="privateApiKey=${privateApiKey}" \
         -n ${namespace}

kubectl label secret mongodb-atlas-operator-api-key atlas.mongodb.com/type=credentials -n ${namespace}

# 2. Create an AtlasProject Custom Resource
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create Project ..."

# open up IP access list
# kubectl delete AtlasProject ${project} > /dev/null 2>&1
cat <<EOF | kubectl apply -f -
apiVersion: atlas.mongodb.com/v1
kind: AtlasProject
metadata:
  name: "${project}"
spec:
  name: "${project}"
  projectIpAccessList:
    - ipAddress: "63.81.44.34"
      comment: "IP address for weWork"
    - ipAddress: "67.188.49.195"
      comment: "IP address for home"
EOF

kubectl get atlasproject ${project} -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
