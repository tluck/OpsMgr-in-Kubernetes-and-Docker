kubectl delete svc my-replica-set-0
kubectl delete svc my-replica-set-1
kubectl delete svc my-replica-set-2

kubectl expose pod my-replica-set-0 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-1 --type="NodePort" --port 27017 -n mongodb
kubectl expose pod my-replica-set-2 --type="NodePort" --port 27017 -n mongodb

out0=( $(kubectl get svc/my-replica-set-0  | grep -v NAME) )
out1=( $(kubectl get svc/my-replica-set-1  | grep -v NAME) )
out2=( $(kubectl get svc/my-replica-set-2  | grep -v NAME) )

np0=${out0[4]:6:5}
np1=${out1[4]:6:5}
np2=${out2[4]:6:5}
out=( $(kubectl describe nodes|grep ExternalDNS) )
if [[ $out == "" ]]
then
    out=( x localhost x localhost x localhost )
fi

cat $1 | sed -e '/nodeport/d' > new
echo "      -" \"nodeport\": \"${out[1]}:$np0\" | tee -a new
echo "      -" \"nodeport\": \"${out[3]}:$np1\" | tee -a new
echo "      -" \"nodeport\": \"${out[5]}:$np2\" | tee -a new
mv new $1

