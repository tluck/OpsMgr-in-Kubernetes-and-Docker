#!/bin/bash

source ../../k8s/init.conf
source docker.conf

while getopts 'i:o:p:v:u:h' opt
do
  case "$opt" in
    i|o) orgId="$OPTARG"     ;;
    p) projectName="$OPTARG" ;;
    u) user="$OPTARG"        ;;
    v) version="$OPTARG"     ;;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done

shift "$(($OPTIND -1))"
projectName="${projectName:-Demo}"
version=${v:-$MONGO_VERSION}

# get latest cert
cp ../../k8s/certs/ca.pem data/ca.pem

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

name="node"
for i in 3 2 1
do
fullName=$( printf "${projectName}-${name}-${i}"| tr '[:upper:]' '[:lower:]' )
kubectl delete pod ${fullName} > /dev/null 2>&1
kubectl delete svc ${fullName} > /dev/null 2>&1
sleep 5
cat node.yaml | sed -e "s/PROJECT-NAME/${fullName}/" -e "s/NAMESPACE/${namespace}/" -e "s/NAME/${name}-${i}/" -e "s/MONGO_VERSION/${version}/" | kubectl apply -f -
done

# external nodeport
i=1
fullName=$( printf "${projectName}-${name}-${i}"| tr '[:upper:]' '[:lower:]' )
kubectl delete svc ${fullName}-ext > /dev/null 2>&1
kubectl expose pod ${fullName} --name="${fullName}-ext" --type="NodePort" --port 27017 -n ${namespace}

pod=pod/${fullName}
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

exit

# connect to first node and make RS
kubectl exec ${fullName} -i -t -- mongosh --eval '
rs.initiate( {
   _id : "RepSet1",
   members: [
      { _id: 0, host: "${fullName}-1:27017" },
      { _id: 1, host: "${fullName}-2:27017" },
      { _id: 2, host: "${fullName}-3:27017" }
   ]
})
'

kubectl exec ${fullName} -i -t -- mongosh --eval 'rs.conf()'

sleep 20
exit

cd ~/proofs/01/
./node1_import.bash
