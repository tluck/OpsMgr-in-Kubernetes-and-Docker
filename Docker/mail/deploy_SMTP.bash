#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
PATH=$PATH:"${d}"/Misc

#source ../init.conf

kubectl delete pod/smtp > /dev/null 2>&1
kubectl run --image=bytemark/smtp --port=25 \
        --env="RELAY_HOST=smtp.gmail.com" --env="RELAY_PORT=587" --env="RELAY_USERNAME=tlucks.demo@gmail.com" --env="RELAY_PASSWORD=Mongodb1$" smtp
        
kubectl delete service smtp-svc > /dev/null 2>&1
kubectl create -f smtp-svc.yaml
