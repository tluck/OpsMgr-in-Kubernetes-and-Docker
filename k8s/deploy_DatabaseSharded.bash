#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:s:xh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    s) shards="$OPTARG" ;;
    x) x="1" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-c arg] [-s shards] [-v version] [-x]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name="${name:-mysharded}"
cpu="${cpu:-0.5}"
mem="${mem:-500Mi}"
dsk="${dsk:-1Gi}"
ver="${ver:-5.0.9-ent}"
shards="${shards:-2}"
cleanup=${x:-0}

# make manifest from template
mdb="mdb_${name}.yaml"
mdbuser="mdbuser_${name}.yaml"

cat mdb_sharded.yaml | sed \
    -e "s/MEM/$mem/" \
    -e "s/CPU/$cpu/" \
    -e "s/DISK/$dsk/" \
    -e "s/VERSION/$ver/" \
    -e "s/NAME/$name/" > $mdb

cat mdbuser_template.yaml | sed \
    -e "s/NAME/$name/" > $mdbuser

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret ${name}-cert > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${name}" | awk '{print $1}' )
  kubectl delete svc $( kubectl get svc | grep "${name}" | awk '{print $1}' )
  kubectl delete mdb ${name}
fi

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
    kubectl delete configmap ${name} > /dev/null 2>&1
    kubectl create configmap ${name} \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates='true'"

  rm certs/${name}*
    # mdb-{metadata.name}-mongos-cert
    # mdb-{metadata.name}-config-cert
    # mdb-{metadata.name}-<x>-cert x=0,1 (2 shards)
  for ctype in agent mongos config 0 1
  do   
    certs/make_sharded_certs.bash ${name} ${ctype}
    # Create a secret for the member certs for TLS
    kubectl delete secret mdb-${name}-${ctype}-cert > /dev/null 2>&1
    kubectl create secret tls mdb-${name}-${ctype}-cert \
        --cert=certs/${name}-${ctype}.crt \
        --key=certs/${name}-${ctype}.key
  done

    # Create a map for the cert
    kubectl delete configmap ca-pem > /dev/null 2>&1
    kubectl create configmap ca-pem \
        --from-file="ca-pem=certs/ca.pem"
else
    kubectl delete configmap ${name} > /dev/null 2>&1
    kubectl create configmap ${name} \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}"
fi #tls

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
kubectl apply -f "${mdb}"

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
tls=$( kubectl get mdb/${name} -o jsonpath='{.spec.security.authentication}' )
if [[ "${tls}" == "map[enabled:true]" || "${tls}" == *"\"enabled\":true"* ]]
then
    eval version=$( kubectl get mdb ${name} -o jsonpath={.spec.version} )
    if [[ ${version%%.*} = 3 ]]
    then
        ssltls_options=" --ssl --sslCAFile certs/ca.pem --sslPEMKeyFile certs/${name}.pem "
        ssltls_enabled="&ssl=true"
    else
        ssltls_options=" --tls --tlsCAFile certs/ca.pem --tlsCertificateKeyFile certs/${name}.pem "
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
  printf "%s\n" "Wait a minute for the reconfiguration and then connect by running: Misc/kub_connect_to_pod.bash ${name}-mongos"
fi

exit 0
