#!/bin/bash

d=$( dirname "$0" )
cd "${d}"

def_token=( $( kubectl get secrets | grep default-token ) )
kubectl get secret ${def_token} -o jsonpath='{.data.ca\.crt}' | base64 -D > ca.crt 
cat downloads.crt ca.crt > ca-pem
ln -f ca-pem mms-ca.crt 
