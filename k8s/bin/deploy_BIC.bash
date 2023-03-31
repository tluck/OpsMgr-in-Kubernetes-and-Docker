#!/bin/bash

source init.conf

while getopts 'n:u:p:t:h' opt
do
  case "$opt" in
    n) name="$OPTARG";;
    u) dbuser="$OPTARG";;
    p) dbpassword="$OPTARG";;
    t) port="$OPTARG";;
    ?|h)
      echo "Usage: $(basename $0) -n clustername [-u dbuser] [-p dbpassword] [-t port] [-h]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myproject1-myreplicaset}
pod=bic-${name}
port=${port:-30307}

get_connection_string.bash -n "${name}"

cat mongosqld_template.yaml | sed \
    -e "s/NAMESPACE/$namespace/g" \
    -e "s/DBUSER/$dbuser/g" \
    -e "s/DBPASSWORD/$dbpassword/g" \
    -e "s/NAME/$name/g" > "${pod}.yaml"

kubectl delete configmap shareddata > /dev/null 2>&1
kubectl create configmap shareddata \
    --from-file=certs/ca.pem \
    --from-file=certs/${name}.pem \
    --from-file=mongosqld-config.yml=${pod}.yaml

kubectl delete pod ${pod} > /dev/null 2>&1
kubectl delete svc ${pod} > /dev/null 2>&1
kubectl delete svc ${pod}-ext > /dev/null 2>&1
cat bic_template.yaml | sed \
    -e "s/PORT/${port}/g" \
    -e "s/NAMESPACE/${namespace}/g" \
    -e "s/NAME/${name}/" | kubectl apply -f -

serviceName="${pod}-svc-ext"
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
printf "%s\n" "bicServer: ${bicServer}"
# external nodeport
#kubectl expose pod ${name} --name="${name}-ext" --type="NodePort" --port 3307 --target-port=3307 -n ${namespace}
