#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

# Create the namespace and context
kubectl config set-context $(kubectl config current-context) --namespace=${namespace}
kubectl create namespace ${namespace}

operatorType=""
[[ "${clusterType}" == "openshift" ]] && operatorType="-openshift"
# Deploy the MongoDB Enterprise Operator
if [[ ! -e mongodb-enterprise${operatorType}.yaml ]] 
then
  curl -s https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise${operatorType}.yaml -o mongodb-enterprise${operatorType}.yaml
  curl -s https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml -o crds.yaml
fi

myOperator="${namespace}-myoperator.yaml"
kubectl apply -f crds.yaml
cat mongodb-enterprise${operatorType}.yaml | sed \
  -e "s/namespace: mongodb/namespace: $namespace/"  > "${myOperator}"

# add recovery feature
cat <<EOF >> "${myOperator}" 
            - name: MDB_AUTOMATIC_RECOVERY_ENABLE
              value: 'true'
            - name: MDB_AUTOMATIC_RECOVERY_BACKOFF_TIME_S
              value: '480'
EOF

kubectl delete deployment mongodb-enterprise-operator > /dev/null 2>&1
kubectl delete deployment mongodb-enterprise-operator-multi-cluster > /dev/null 2>&1
kubectl apply -f "${myOperator}"

if [[ ${tls} == true ]] 
then
    which cfssl > /dev/null
    if [[ $? != 0 ]]
    then
        printf "%s\n" "Exiting - Missing cloudformation certificiate tools - install cfssl and cfssljson"
        exit 1
    fi
    certs/make_cert_issuer.bash ${namespace} ${issuerName} ${issuerVersion}
    [[ $? != 0 ]] && exit 1
fi
exit 0
