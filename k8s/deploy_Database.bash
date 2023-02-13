#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:l:o:p:g:xh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    l) ldap="$OPTARG" ;;
    o) orgId="$OPTARG";;
    p) projectName="$OPTARG";;
    g) skipMakeCerts=1 ;;
    x) x="1" ;; # cleanup
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-v ver] [-l ldap[s]] [-o orgId] [-p projectName] [-g] [-x] [-s shards] [-r mongos]"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name="${name:-myreplicaset}"
cpu="${cpu:-0.5}"
mem="${mem:-500Mi}"
dsk="${dsk:-1Gi}"
ver="${ver:-$mdbVersion}"
cleanup=${x:-0}
projectName="${projectName:-$name}"
fullname=$( printf "${projectName}-${name}"| tr '[:upper:]' '[:lower:]' )
skipMakeCerts=${skipMakeCerts:-0}

# make manifest from template
mdb="mdb_${fullname}.yaml"
mdbuser="mdbuser_${fullname}.yaml"
if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  mdbuser2="mdbuser_${fullname}_ldap.yaml"
fi

tlsc="#TLS "
tlsr=$tlsc
if [[ ${tls} == 1 ]]
then
tlsr=""
fi

if [[ ${ldap} == 'ldaps' ]]
then
    LDAPT=""
    ldaptls="tls"
else
    LDAPT="#LDAPT "
    ldaptls="none"
fi

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  cat mdb_template_rs.yaml | sed \
      -e "s|$tlsc|$tlsr|" \
      -e "s|VERSION|$ver|" \
      -e "s|MEM|$mem|" \
      -e "s|CPU|$cpu|" \
      -e "s|DISK|$dsk|" \
      -e "s|NAMESPACE|$namespace|" \
      -e "s|#LDAP  ||" \
      -e "s|#LDAPT |$LDAPT|" \
      -e "s|LDAPTLS|$ldaptls|" \
      -e "s|LDAPBINDQUERYUSER|$ldapBindQueryUser|" \
      -e "s|LDAPAUTHZQUERYTEMPLATE|$ldapAuthzQueryTemplate|" \
      -e "s|LDAPUSERTODNMAPPING|$ldapUserToDNMapping|" \
      -e "s|LDAPTIMEOUTMS|$ldapTimeoutMS|" \
      -e "s|LDAPUSERCACHEINVALIDATIONINTERVAL|$ldapUserCacheInvalidationInterval|" \
      -e "s|LDAPSERVER|$ldapServer|" \
      -e "s|LDAPCERTMAPNAME|$ldapCertMapName|" \
      -e "s|LDAPKEY|$ldapKey|" \
      -e "s|PROJECT-NAME|$fullname|" > "$mdb"
else
  cat mdb_template_rs.yaml | sed \
      -e "s|$tlsc|$tlsr|" \
      -e "s|VERSION|$ver|" \
      -e "s|MEM|$mem|" \
      -e "s|CPU|$cpu|" \
      -e "s|DISK|$dsk|" \
      -e "s|NAMESPACE|$namespace|" \
      -e "s|#X509  ||" \
      -e "s|PROJECT-NAME|$fullname|" > "$mdb"
fi

#dbuserlc=${dbuser,,}
dbuserlc=$( printf "$dbuser" | tr '[:upper:]' '[:lower:]' )
cat mdbuser_template.yaml | sed \
      -e "s|NAME-USER|${fullname}-${dbuserlc//_}|" \
      -e "s|NAME|${fullname}|" \
      -e "s|USER|${dbuserlc}|" > "$mdbuser"

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  ldapuserlc=$( printf "$ldapUser" | tr '[:upper:]' '[:lower:]' )
  cat mdbuser_template_ldap.yaml | sed \
      -e "s|NAME-USER|${fullname}-${ldapuserlc//_}|" \
      -e "s|NAME|${fullname}|" \
      -e "s|USER|${ldapuserlc}|" > "$mdbuser2"
fi

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret "${fullname}-cert" > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${fullname}" | awk '{print $1}' )
  kubectl delete mdb "${fullname}" 2>&1 > /dev/null
  kubectl delete pvc $( kubectl get pvc | grep "${fullname}-" | awk '{print $1}' ) 2>&1 > /dev/null
  kubectl delete svc $( kubectl get svc | grep "${fullname}-" | awk '{print $1}' ) 2>&1 > /dev/null
  kubectl delete configmaps $( kubectl get configmaps | grep "${fullname} " | awk '{print $1}' ) 2>&1 > /dev/null
  kubectl delete secrets $( kubectl get secrets | grep "${fullname}-" | awk '{print $1}' ) 2>&1 > /dev/null
fi

# create new certs if the service does not exist
# check to see if the svc needs to be created
for n in ${exposed_dbs[@]}
do
  if [[ "$n" == "${fullname}" ]] 
  then
    printf "%s\n" "Generating ${serviceType} Service ports..."
    serviceOut=$( bin/expose_service.bash "${mdb}" ${cleanup} ) 
    dnsHorizon=( $( printf "${serviceOut}" | tail -n 1 ) )
    if [[ $? != 0 ]]
    then
        printf "* * * Error - failed to configure splitHorizon for ${fullname}:\n" 
        exit 1
    fi
    printf "${serviceOut}"| head -n 7
    printf "...added these hostnames to the manifest ${mdb}:\n" 
    printf "\t%s\n" "${dnsHorizon[0]}"
    printf "\t%s\n" "${dnsHorizon[1]}"
    printf "\t%s\n" "${dnsHorizon[2]}"
    printf "\n"
    eval tail -n 5 "${mdb}"
    printf "\n"
  fi
done

# Create map for OM Org/Project
if [[ ${tls} == 1 && ${skipMakeCerts} == 0 ]]
then
kubectl delete configmap "${fullname}" > /dev/null 2>&1
if [[ $orgId != "" ]]
then
kubectl create configmap "${fullname}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="orgId=${orgId}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
    --from-literal="sslRequireValidMMSServerCertificates='true'"
else
kubectl create configmap "${fullname}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
    --from-literal="sslRequireValidMMSServerCertificates='true'"
fi

rm "${PWD}/certs/${fullname}"* > /dev/null 2>&1
if [[ ${#dnsHorizon[@]} != 0  ]] 
then
#  dnsHorizon=( $(cat dnsHorizon) )
#  rm dnsHorizon
  "${PWD}/certs/make_db_certs.bash" "${fullname}" ${dnsHorizon[@]}
else
  "${PWD}/certs/make_db_certs.bash" "${fullname}"
fi
# Create a secret for the member certs for TLS
# kubectl delete secret "mdb-${fullname}-cert" "mdb-${fullname}-cert-pem" > /dev/null 2>&1
kubectl delete secret "mdb-${fullname}-cert" > /dev/null 2>&1
kubectl create secret tls "mdb-${fullname}-cert" \
    --cert="${PWD}/certs/${fullname}.crt" \
    --key="${PWD}/certs/${fullname}.key"

for ctype in agent clusterfile
do   
    "${PWD}/certs/make_sharded_certs.bash" "${fullname}" ${ctype}
    # Create a secret for the member certs for TLS
    cert=""
    if [[ "${ctype}" == "agent" ]]
    then
    cert="-certs"
    fi
    kubectl delete secret "mdb-${fullname}-${ctype}${cert}" > /dev/null 2>&1
    kubectl create secret tls "mdb-${fullname}-${ctype}${cert}" \
        --cert="${PWD}/certs/${fullname}-${ctype}.crt" \
        --key="${PWD}/certs/${fullname}-${ctype}.key"
done

# Create a map for the cert
kubectl delete configmap ca-pem > /dev/null 2>&1
kubectl create configmap ca-pem \
    --from-file="ca-pem=${PWD}/certs/ca.pem"
else
  if [[ $orgId != "" ]]
  then
    kubectl delete configmap "${fullname}" > /dev/null 2>&1
    kubectl create configmap "${fullname}" \
    --from-literal="orgId=${orgId}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${projectName}"
  else
    kubectl delete configmap "${fullname}" > /dev/null 2>&1
    kubectl create configmap "${fullname}" \
    --from-literal="baseUrl=${opsMgrUrl}" \
    --from-literal="projectName=${projectName}"
  fi
fi # tls

# Create a a secret for db user credentials
kubectl delete secret         ${fullname}-${dbuserlc} > /dev/null 2>&1
kubectl create secret generic ${fullname}-${dbuserlc} \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}"

# Create the User Resource
kubectl apply -f "${mdbuser}"

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  kubectl apply -f "${mdbuser2}"
  kubectl delete secret         "${fullname}-ldapsecret" > /dev/null 2>&1
  kubectl create secret generic "${fullname}-ldapsecret" \
    --from-literal=password="${ldapBindQueryPassword}" 
fi

# remove any certificate requests
list=( $( kubectl get csr 2>/dev/null | grep "${fullname}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
    kubectl delete csr ${list[@]} > /dev/null 2>&1
fi

# Create the DB Resource
kubectl apply -f "${mdb}"

# Monitor the progress
resource="mongodb/${fullname}"
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
cs=$( bin/get_connection_string.bash -n "${fullname}" )
if [[ "$cs" == *external* ]]
then
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect directly by running: bin/connect_external.bash -n \"${fullname}\""
    printf "%s\n" "                      or connect from the pod by running: bin/connect_from_pod.bash -n \"${fullname}\""
else
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect from the pod by running: bin/connect_from_pod.bash -n \"${fullname}\""
fi
exit 0
