#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source ../init.conf

name="${1:-mydb}"
mdb="mdb_${name}.yaml"
mdbuser="mdbuser_${name}.yaml"
shift
cleanup=${1:-0}

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret ${name}-cert > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${name}" | awk '{print $1}' )
  kubectl delete svc $( kubectl get svc | grep "${name}" | awk '{print $1}' )
  kubectl delete mdb ${name}
fi

# create new certs if the service does not exist
# check to see if the svc needs to be created
for n in ${exposed_dbs[@]}
do
  if [[ "$n" == "${name}" ]] 
  then
  # kubectl get svc ${name}-0 > /dev/null 2>&1
  # if [[ $? != 0 ]]
  # then
    # expose ports - creates loadlancer or nodeport service for each pod of member set
    # add the nodeport map for splitHorizon into the yaml file
    printf "%s\n" "Generating NodePort/Loadbalancer Service ports..."
    Misc/expose_service.bash ${mdb} ${cleanup}
    source init.conf
  # fi
  fi
done

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
kubectl delete configmap ${name} > /dev/null 2>&1
kubectl create configmap ${name} \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${name}" \
    --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
    --from-literal="sslRequireValidMMSServerCertificates='true'"

# rm certs/${name}*
# if [[ -e dnsHorizon ]] 
# then
#   dnsHorizon=( $(cat dnsHorizon) )
#   rm dnsHorizon
#   certs/make_db_certs.bash ${name} ${dnsHorizon[@]}
# else
#   certs/make_db_certs.bash ${name}
# fi
# # Create a secret for the member certs for TLS
# kubectl delete secret mdb-${name}-cert > /dev/null 2>&1
# # sleep 3
# # kubectl get secrets
# kubectl create secret tls mdb-${name}-cert \
#     --cert=certs/${name}.crt \
#     --key=certs/${name}.key

# # Create a map for the cert
# kubectl delete configmap ca-pem > /dev/null 2>&1
# kubectl create configmap ca-pem \
#     --from-file="ca-pem=certs/ca.pem"
else
kubectl delete configmap ${name} > /dev/null 2>&1
kubectl create configmap ${name} \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${name}"
fi

# Create a a secret for db user credentials
kubectl delete secret         dbadmin-${name} > /dev/null 2>&1
kubectl create secret generic dbadmin-${name} \
    --from-literal=name="${dbadmin}" \
    --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"

# Create the DB Resource
list=( $( kubectl get csr | grep "${name}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
kubectl delete csr ${list[@]}
fi

helm install mydb enterprise-database
#kubectl apply -f "${mdb}"

# Monitor the progress
notapproved="Not all certificates have been approved"
certificate="Certificate"
pod=mongodb/${name}
while true
do
    kubectl get ${pod}
    eval status=$(  kubectl get ${pod} -o json| jq '.status.phase' )
    eval message=$( kubectl get ${pod} -o json| jq '.status.message' )
    printf "%s\n" "status.message: $message"
    if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    then
        # TLS Cert approval (if using autogenerated certs -- deprecated)
        kubectl certificate approve $( kubectl get csr | grep "Pending" | awk '{print $1}' )
    fi
    #if [[ $status == "Pending" || $status == "Running" ]];
    if [[ "$status" == "Running" ]];
    then
        printf "%s\n" "$status"
        break
    fi
    sleep 15
done

# get keys for TLS
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.tls}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"\"enabled\":true"* ]]
then
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile ca.pem --sslPEMKeyFile server.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile ca.pem --tlsCertificateKeyFile server.pem "
        ssltls_enabled="&tls=true"
    fi
fi

eval cs=\$${name//-/}_URI
if [[ "$cs" != "" ]]
then
  printf "\n"
  printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/connect_external.bash ${name}"
  fcs=\'${cs}${ssltls_enabled}\'
  printf "\n%s\n\n" "Connect String: ${fcs} ${ssltls_options}"
else
  printf "\n"
  printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/kub_connect_to_pod.bash ${name}"
fi

exit 0
