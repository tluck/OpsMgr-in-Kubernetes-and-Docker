#!/bin/bash

def_token=( $( kubectl get secrets | grep default-token ) )
kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > mms-ca.crt 
ln -sf mms-ca.crt ca-pem
