#!/bin/bash

# get latest cert
cp ../../k8s/certs/ca-pem data/ca.pem

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

name=mongodb
for i in 1 2 3
do
kubectl delete pod ${name}${i} > /dev/null 2>&1
kubectl delete svc ${name}${i} > /dev/null 2>&1
cat node.yaml | sed -e "s/NAME/${name}${i}/" | kubectl apply -f -
done

pod=pod/${name}${i}
while true
do
    kubectl get ${pod}
    eval status=$(  kubectl get ${pod} -o json| jq '.status.phase' )
    eval message=$( kubectl get ${pod} -o json| jq '.status.message')
    printf "%s\n" "$message"
    if [[ "$status" == "Running" ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 15
done

# connect to first node and make RS
kubectl exec ${name}1 -- mongo --eval '
rs.initiate( {
   _id : "RepSet1",
   members: [
      { _id: 0, host: "mongodb1:27017" },
      { _id: 1, host: "mongodb2:27017" },
      { _id: 2, host: "mongodb3:27017" }
   ]
})
'

