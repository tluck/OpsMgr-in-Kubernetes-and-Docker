kubectl expose pod my-replica-set-0 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-1 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-2 --type="NodePort" --port 27017 -n mongodb

kubectl get svc  | grep my-replica-set
