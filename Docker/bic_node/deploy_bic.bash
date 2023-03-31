#!/bin/bash

source ../../k8s/init.conf

while getopts 'n:u:h' opt
do
  case "$opt" in
    n) name="$OPTARG";;
    u) user="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -o orgName [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myproject1-myreplicaset}
fullName=bic-${name}

# get latest cert
cp ../../k8s/certs/ca.pem data/ca.pem

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=data/ca.pem \
    --from-file=data/${name}.pem \
    --from-file=data/mongosqld-config.yml

kubectl delete pod ${fullName} > /dev/null 2>&1
kubectl delete svc ${fullName} > /dev/null 2>&1
kubectl delete svc ${fullName}-ext > /dev/null 2>&1
cat bic.yaml | sed -e "s/NAMESPACE/${namespace}/" -e "s/NAME/${fullName}/" | kubectl apply -f -

serviceName="${fullName}-ext"
if [[ $serviceType == "NodePort" ]]
then
    slist=( $(get_hns.bash -s "${serviceName}" ) ) 
    hostName="${slist[0]%:*}"
    eval port=$(    kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].nodePort} )
else
    eval hostName=$(    kubectl get svc/${serviceName} -o jsonpath={.status.loadBalancer.ingress[0].hostname} ) 
    if [[ $hostName == "" ]]
    then
    slist=( $(get_hns.bash -s "${serviceName}" ) ) 
    hostName="${slist[0]%:*}"
    fi
    eval port=$(  kubectl get svc/${serviceName} -o jsonpath={.spec.ports[0].targetPort} )
fi
bicServer="${hostName}:${port}"

# external nodeport
#kubectl expose pod ${name} --name="${name}-ext" --type="NodePort" --port 3307 --target-port=3307 -n ${namespace}
