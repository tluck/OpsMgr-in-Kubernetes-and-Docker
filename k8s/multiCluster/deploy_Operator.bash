#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

# Create the namespace and context
kubectl config use-context $MDB_CENTRAL_C_CONTEXT
kubectl config set-context $(kubectl config current-context) --namespace=${mcNamespace}
kubectl create namespace ${mcNamespace}

# Deploy the MongoDB Enterprise Operator
myOperator="${mcNamespace}-myoperator.yaml"
kubectl apply -f crds.yaml

operator=mongodb-enterprise-multi-cluster.yaml
cat ${operator}| sed \
    -e "s/namespace: mongodb/namespace: $mcNamespace/"  > "${myOperator}"

# kill off any existing operator
kubectl delete deployment mongodb-enterprise-operator > /dev/null 2>&1 
kubectl delete deployment mongodb-enterprise-operator-multi-cluster > /dev/null 2>&1
kubectl apply -f "${myOperator}"

# set up roles for multi-cluster environment
sleep 3
kubectl mongodb multicluster setup \
     --central-cluster="${MDB_CENTRAL_C_CONTEXT}" \
     --central-cluster-namespace="${mcNamespace}" \
     --member-clusters="${MDB_CLUSTER_0_CONTEXT},${MDB_CLUSTER_1_CONTEXT},${MDB_CLUSTER_2_CONTEXT}" \
     --member-cluster-namespace="${mcNamespace}" \
     --create-service-account-secrets  \
     --install-database-roles=true

# set up istio
_istio_webhook.bash

if [[ ${tls} == true ]] 
then
    which cfssl > /dev/null
    if [[ $? != 0 ]]
    then
        printf "%s\n" "Exiting - Missing cloudformation certificiate tools - install cfssl and cfssljson"
        exit 1
    fi
    certs/make_cert_issuer.bash ${mcNamespace} ${issuerName} ${issuerVersion}
    [[ $? != 0 ]] && exit 1
fi
exit 0
