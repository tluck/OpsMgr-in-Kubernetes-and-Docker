kubectl create secret generic my-replica-set-cert \
  --from-file=my-replica-set-0-pem \
  --from-file=my-replica-set-1-pem \
  --from-file=my-replica-set-2-pem

kubectl create configmap ca-pem --from-file=ca-pem
