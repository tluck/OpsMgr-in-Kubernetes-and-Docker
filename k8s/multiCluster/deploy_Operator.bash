#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

# Create the namespace and context
kubectl config use-context $MDB_CENTRAL_C_CONTEXT
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}
kubectl create namespace ${namespace}

# Deploy the MongoDB Enterprise Operator
myOperator="${namespace}-myoperator.yaml"
kubectl apply -f crds.yaml

# Note: this is a custom operator for now.
cat mc-operator.yaml | sed \
    -e "s/namespace: mongodb/namespace: $namespace/"  > "${myOperator}"

kubectl delete deployment mongodb-enterprise-operator
kubectl apply -f "${myOperator}"

# set up roles for multi-cluster environment
sleep 3
kubectl mongodb multicluster setup \
     --central-cluster="${MDB_CENTRAL_C_CONTEXT}" \
     --central-cluster-namespace="${namespace}" \
     --member-clusters="${MDB_CLUSTER_0_CONTEXT},${MDB_CLUSTER_1_CONTEXT},${MDB_CLUSTER_2_CONTEXT}" \
     --member-cluster-namespace="${namespace}" \
     --create-service-account-secrets  \
     --install-database-roles=true

# set up istio
_istio_webhook.bash

if [[ ${tls} == true ]] 
then
    certs/make_cert_issuer.bash ${namespace} ${issuerName} ${issuerVersion}
    [[ $? != 0 ]] && exit 1
fi
exit 0
