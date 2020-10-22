#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

source init.conf

kubectl delete pod/smtp > /dev/null 2>&1
kubectl run --image=bytemark/smtp --port=25 \
        --env="RELAY_HOST=smtp.gmail.com" --env="RELAY_PORT=587" --env="RELAY_USERNAME=${RELAY_USERNAME}" --env="RELAY_PASSWORD=${RELAY_PASSWORD}" smtp
        
kubectl delete service smtp-svc > /dev/null 2>&1
kubectl create -f smtp-svc.yaml
