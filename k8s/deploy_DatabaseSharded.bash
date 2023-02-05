#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:s:r:xh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    s) shards="$OPTARG" ;;
    r) mongos="$OPTARG" ;;
    x) x="1" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-c arg] [-s shards] [-r mongos] [-v version] [-x]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name="${name:-mysharded}"
ver="${ver:-$mdbVersion}"
mem="${mem:-2Gi}"
cpu="${cpu:-1.0}"
dsk="${dsk:-1Gi}"
shards="${shards:-2}"
mongos="${mongos:-1}"
cleanup=${x:-0}

# mongos and configServer resources (good for a demo)
msmem="2Gi"
mscpu="0.5"
csmem="2Gi"
cscpu="0.5"

# make manifest from template
mdbuser="mdbuser_${name}.yaml"
mdb="mdb_${name}.yaml"
tlsc="#TLS "
tlsr=$tlsc
if [[ ${tls} == 1 ]]
then
tlsr=""
fi
cat mdb_sharded.yaml | sed \
    -e "s/$tlsc/$tlsr/" \
    -e "s/VERSION/$ver/" \
    -e "s/DBMEM/$mem/" \
    -e "s/DBCPU/$cpu/" \
    -e "s/DISK/$dsk/" \
    -e "s/SHARDS/$shards/" \
    -e "s/MONGOS/$mongos/" \
    -e "s/CSCPU/$cscpu/" \
    -e "s/CSMEM/$csmem/" \
    -e "s/MSCPU/$mscpu/" \
    -e "s/MSMEM/$msmem/" \
    -e "s/NAMESPACE/$namespace/" \
    -e "s/NAME/$name/" > "$mdb"

dbuserlc=$( printf "$dbuser" | tr '[:upper:]' '[:lower:]' )
cat mdbuser_template.yaml | sed \
    -e "s/NAME/${name}/" \
    -e "s/USER/${dbuserlc}/" > "$mdbuser"

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret "${name}-cert" > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${name}" | awk '{print $1}' )
  kubectl delete mdb "${name}"
  kubectl delete pvc $( kubectl get pvc | grep "${name}" | awk '{print $1}' )
  kubectl delete svc $( kubectl get svc | grep "${name}" | awk '{print $1}' )
fi

# Create map for OM Org/Project
if [[ ${tls} == 1 ]]
then
    kubectl delete configmap "${name}" > /dev/null 2>&1
    kubectl create configmap "${name}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates='true'"

  rm "${PWD}/certs/${name}"*  > /dev/null 2>&1
    # mdb-{metadata.name}-mongos-cert
    # mdb-{metadata.name}-config-cert
    # mdb-{metadata.name}-<x>-cert x=0,1 (2 shards)
  for ctype in agent mongos config $( seq -s " " 0 $(( $shards-1)) )
  do   
    "${PWD}/certs/make_sharded_certs.bash" "${name}" ${ctype}
    # Create a secret for the member certs for TLS
    cert="-cert"
    if [[ "${ctype}" == "agent" ]]
    then
    cert="-certs"
    fi
    kubectl delete secret "mdb-${name}-${ctype}${cert}" > /dev/null 2>&1
    kubectl create secret tls "mdb-${name}-${ctype}${cert}" \
        --cert="${PWD}/certs/${name}-${ctype}.crt" \
        --key="${PWD}/certs/${name}-${ctype}.key"
  done

    # Create a map for the cert
    kubectl delete configmap ca-pem > /dev/null 2>&1
    kubectl create configmap ca-pem \
        --from-file="ca-pem=${PWD}/certs/ca.pem"
else
    kubectl delete configmap "${name}" > /dev/null 2>&1
    kubectl create configmap "${name}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${name}"
fi # tls

# Create a a secret for db user credentials
kubectl delete secret         ${name}-${dbuserlc} > /dev/null 2>&1
kubectl create secret generic ${name}-${dbuserlc} \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"


# remove any certificate requests
list=( $( kubectl get csr 2>/dev/null | grep "${name}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
    kubectl delete csr ${list[@]} > /dev/null 2>&1
fi

# Create the DB Resource
kubectl apply -f "${mdb}"

# Monitor the progress
resource="mongodb/${name}"
printf "\n%s\n" "Monitoring the progress of resource ${resource} ..."
notapproved="Not all certificates have been approved"
certificate="Certificate"
while true
do
    kubectl get "${resource}"
    pstatus=$( kubectl get "${resource}" -o jsonpath={'.status.phase'} )
    message=$( kubectl get "${resource}" -o jsonpath={'.status.message'} )
    printf "%s\n" "status.message: $message"
    if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    then
        # TLS Cert approval (if using autogenerated certs -- deprecated)
        kubectl certificate approve $( kubectl get csr | grep "Pending" | awk '{print $1}' )
    fi
    #if [[ "$pstatus" == "Pending" || "$pstatus" == "Running" ]];
    if [[ "$pstatus" == "Running" ]];
    then
        printf "Status: %s\n" "$pstatus"
        break
    fi
    sleep 15
done

sleep 5
printf "\n"
cs=$( bin/get_connection_string.bash -n "${name}" )
if [[ "$cs" == *external* ]]
then
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect directly by running: bin/connect_external.bash -n \"${name}\""
    printf "%s\n" "                      or connect from the pod by running: bin/connect_from_pod.bash -n \"${name}\""
else
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect from the pod by running: bin/connect_from_pod.bash -n \"${name}\""
fi
exit 0
