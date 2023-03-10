#!/bin/bash

source ../../k8s/init.conf

while getopts 'i:o:p:u:h' opt
do
  case "$opt" in
    i|o) orgId="$OPTARG";;
    p) projectName="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

projectName="${projectName:-Demo}"

# get latest cert
cp ../../k8s/certs/ca.pem data/ca.pem

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=ca.pem=data/ca.pem \
    --from-file=data/automation-agent.config \
    --from-file=data/mongod.conf

name=node-
for i in 1 2 3 #4 5 6 7 8 9 0
do
fullName=$( printf "${projectName}-${name}${i}"| tr '[:upper:]' '[:lower:]' )
kubectl delete pod ${fullName} > /dev/null 2>&1
kubectl delete svc ${fullName} > /dev/null 2>&1
sleep 5
cat node.yaml | sed -e "s/PROJECT-NAME/${fullName}/" -e "s/NAMESPACE/${namespace}/" -e "s/NAME/${name}${i}/" | kubectl apply -f -
done
