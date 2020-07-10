#!/bin/bash

source init.conf

Misc/expose.bash ops-mgr-resource-my-replica-set-secure-auth.yaml
kubectl apply -f ops-mgr-resource-my-replica-set-secure-auth.yaml

# Monitor the progress
while true
do
    kubectl get mongodb/my-replica-set
    eval status=$( kubectl get mongodb/my-replica-set -o json| jq '.status.phase' )
    kubectl get mongodb/my-replica-set -o json| jq '.status.message' 
    #if [[ $status == "Pending" || $status == "Running" ]];
    if [[ $status == "Running" ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 10
done

exit

# Alternate way to monitor - wait for last pod in the set
while true
do
    status=$( kubectl wait --for condition=ready pod/my-replica-set-2 )
    if [[ $? == 0 ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 10
done
