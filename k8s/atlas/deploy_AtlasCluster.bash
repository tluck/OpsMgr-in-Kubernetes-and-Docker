#!/bin/bash

source init.conf

#3. Create an AtlasCluster Custom Resource.
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Cluster ..."
cat <<EOF | kubectl apply -f -
apiVersion: atlas.mongodb.com/v1
kind: AtlasDeployment
metadata:
  name: "${cluster}"
spec:
  projectRef:
    name: "${project}" 
  deploymentSpec:
    name: "${cluster}"
    providerSettings:
      instanceSizeName: M10
      providerName: AWS
      regionName: US_WEST_2
EOF

#4. Create a database user password Kubernetes Secret
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the DB User Secrets ..."

kubectl delete secret dbadmin-password > /dev/null 2>&1
kubectl create secret generic dbadmin-password \
    --from-literal="password=${dbpassword}"
kubectl label secret dbadmin-password atlas.mongodb.com/type=credentials

#5. Create an AtlasDatabaseUser Custom Resource
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the DB User ..."

kubectl delete AtlasDatabaseUser dbadmin-user > /dev/null 2>&1
cat <<EOF | kubectl apply -f -
apiVersion: atlas.mongodb.com/v1
kind: AtlasDatabaseUser
metadata:
  name: dbadmin-user
spec:
  roles:
    - roleName: "readWriteAnyDatabase"
      databaseName: "admin"
  projectRef:
    name: "${project}"
  username: "${dbadmin}"
  passwordSecretRef:
    name: dbadmin-password
EOF

#6. Wait for the AtlasDatabaseUser Custom Resource to be ready

# Monitor the progress
printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Monitoring the Cluster Progress ..."

while true 
do
    sleep 15
    # kubectl get atlascluster ${cluster}
    status=$( kubectl get atlasdeployment ${cluster} -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' )
    printf "%s\n" "Status Messages:"
    kubectl get atlasdeployment ${cluster} -o json | jq '.status.conditions[2]' 
    # if [[ "$status" == "Pending" || "$status" == "Running" ]];
    if [[ "$status" == "True" ]]
    then
        printf "Cluster is Ready\n"
        break
    fi
done

# kubectl get atlasdatabaseusers dbadmin-user -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# kubectl get atlascluster ${cluster} -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
