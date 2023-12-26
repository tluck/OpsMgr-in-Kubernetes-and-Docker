#!/bin/bash

source init.conf

[[ ${demo} ]] && serviceType="NodePort"

kubectl config set-context $(kubectl config current-context) --namespace=${namespace}

kubectl -n $namespace delete secret openldap  > /dev/null 2>&1 
kubectl -n $namespace create secret generic openldap \
    --from-literal=adminpassword=${ldapBindQueryPassword} \
    --from-literal=users=dbAdmin,user01,user02 \
    --from-literal=passwords=Mongodb1,Mongodb1,Mongodb1
kubectl -n $namespace delete svc openldap openldap-svc-ext > /dev/null 2>&1 
kubectl -n $namespace delete Deployment openldap  > /dev/null 2>&1 
cat openldap.yaml | sed  -e "s/SERVICETYPE/$serviceType/g" > myopenldap.yaml
kubectl -n $namespace create -f myopenldap.yaml 

resource="deployment/openldap"
printf "%s\n" "Waiting on ldapServer Readiness..."
while true
do
    sleep 20
    eval pstatus=$( kubectl get "${resource}" -o jsonpath={'.status.conditions[0].status'} )
    if [[ "$pstatus" == "True" ]];
    then
        printf "Status: %s\n" "ldapServer is ready: $pstatus"
        break
    fi
done

sleep 5

ldap_configure.bash
