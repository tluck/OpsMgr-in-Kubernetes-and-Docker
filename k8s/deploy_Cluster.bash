#!/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:l:s:r:o:p:g:xh' opt
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
    s) shards="$OPTARG" ;;
    r) mongos="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-v ver] [-s shards] [-r mongos] [-l ldap[s]] [-o orgId] [-p projectName] [-g] [-x]"
      echo "Usage:      use -x for total clean up before (re)deployment"
      echo "Usage:      use -g to not recreate the certs."
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [[ $shards != "" || $mongos != "" ]]
then
    sharded=1
    shards="${shards:-2}"
    mongos="${mongos:-1}"
    name="${name:-mysharded}"
    template="mdb_template_sh.yaml"
    # mongos and configServer resources (good for a demo) 
    msmem="2Gi"
    mscpu="0.5"
    csmem="2Gi"
    cscpu="0.5"
else
    name="${name:-myreplicset}"
    template="${name:-myreplicaset}"
    template="mdb_template_rs.yaml"
fi

ver="${ver:-$mdbVersion}"
mem="${mem:-2Gi}"
cpu="${cpu:-1.0}"
dsk="${dsk:-1Gi}"
cleanup=${x:-0}
projectName="${projectName:-$name}"
fullName=$( printf "${projectName}-${name}"| tr '[:upper:]' '[:lower:]' )
skipMakeCerts=${skipMakeCerts:-0}

# make manifest from template
mdb="mdb_${fullName}.yaml"
mdbuser1="mdbuser_${fullName}_admin.yaml"
if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  mdbuser2="mdbuser_${fullName}_ldap.yaml"
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
  cat ${template} | sed \
    -e "s|$tlsc|$tlsr|" \
    -e "s|VERSION|$ver|" \
    -e "s|RSMEM|$mem|" \
    -e "s|RSCPU|$cpu|" \
    -e "s|RSDISK|$dsk|" \
    -e "s|SHARDS|$shards|" \
    -e "s|MONGOS|$mongos|" \
    -e "s|CSCPU|$cscpu|" \
    -e "s|CSMEM|$csmem|" \
    -e "s|MSCPU|$mscpu|" \
    -e "s|MSMEM|$msmem|" \
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
    -e "s|PROJECT-NAME|$fullName|" > "$mdb"
else
  cat ${template} | sed \
    -e "s|$tlsc|$tlsr|" \
    -e "s|VERSION|$ver|" \
    -e "s|RSMEM|$mem|" \
    -e "s|RSCPU|$cpu|" \
    -e "s|RSDISK|$dsk|" \
    -e "s|SHARDS|$shards|" \
    -e "s|MONGOS|$mongos|" \
    -e "s|CSCPU|$cscpu|" \
    -e "s|CSMEM|$csmem|" \
    -e "s|MSCPU|$mscpu|" \
    -e "s|MSMEM|$msmem|" \
    -e "s|NAMESPACE|$namespace|" \
    -e "s|#X509  ||" \
    -e "s|PROJECT-NAME|$fullName|" > "$mdb"
fi

cat mdbuser_template_admin.yaml | sed \
    -e "s|NAME|${fullName}|" \
    -e "s|USER|${dbuser}|" > "$mdbuser1"

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  cat mdbuser_template_ldap.yaml | sed \
      -e "s|NAME|${fullName}|" \
      -e "s|USER|${ldapUser}|" > "$mdbuser2"
fi

# clean up any previous certs and services
if [[ ${cleanup} = 1 ]]
then
  #kubectl delete secret "${fullName}-cert" > /dev/null 2>&1
  #kubectl delete csr $( kubectl get csr | grep "${fullName}" | awk '{print $1}' )
  kubectl delete mdb "${fullName}"  > /dev/null 2>&1
  kubectl delete pvc $( kubectl get pvc | grep "${fullName}-" | awk '{print $1}' ) > /dev/null 2>&1
  kubectl delete svc $( kubectl get svc | grep "${fullName}-" | awk '{print $1}' ) > /dev/null 2>&1
  kubectl delete configmaps $( kubectl get configmaps | grep "${fullName} " | awk '{print $1}' )  > /dev/null 2>&1
  kubectl delete secrets $( kubectl get secrets | grep "${fullName}-" | awk '{print $1}' )  > /dev/null 2>&1
fi

# Create map for OM Org/Project
if [[ ${tls} == 1 && ${skipMakeCerts} == 0 ]]
then
  kubectl delete configmap "${fullName}" > /dev/null 2>&1
  if [[ $orgId != "" ]]
  then
    kubectl create configmap "${fullName}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="orgId=${orgId}" \
        --from-literal="projectName=${projectName}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates='true'"
  else
    kubectl create configmap "${fullName}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="projectName=${projectName}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates='true'"
  fi

  if [[ ${sharded} == 1 ]]
  then
    rm "${PWD}/certs/${fullName}"*  > /dev/null 2>&1
      # mdb-{metadata.name}-mongos-cert
      # mdb-{metadata.name}-config-cert
      # mdb-{metadata.name}-<x>-cert x=0,1 (2 shards)
    for ctype in agent mongos config $( seq -s " " 0 $(( $shards-1)) )
    do   
      "${PWD}/certs/make_sharded_certs.bash" "${fullName}" ${ctype}
      # Create a secret for the member certs for TLS
      cert="-cert"
      if [[ "${ctype}" == "agent" ]]
      then
      cert="-certs"
      fi
      kubectl delete secret "mdb-${fullName}-${ctype}${cert}" > /dev/null 2>&1
      kubectl create secret tls "mdb-${fullName}-${ctype}${cert}" \
          --cert="${PWD}/certs/${fullName}-${ctype}.crt" \
          --key="${PWD}/certs/${fullName}-${ctype}.key"
    done
  else 
    # ReplicaSet
    # create new certs if the service does not exist
    # check to see if the external svc needs to be created
    for n in ${exposed_dbs[@]}
    do
      if [[ "$n" == "${fullName}" ]] 
      then
        printf "%s\n" "Generating ${serviceType} Service ports..."
        serviceOut=$( bin/expose_service.bash "${mdb}" ${cleanup} ) 
        dnsHorizon=( $( printf "${serviceOut}" | tail -n 1 ) )
        if [[ $? != 0 ]]
        then
            printf "* * * Error - failed to configure splitHorizon for ${fullName}:\n" 
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
    # now make the certs
    rm "${PWD}/certs/${fullName}"* > /dev/null 2>&1
    if [[ ${#dnsHorizon[@]} != 0  ]] 
    then
      #  dnsHorizon=( $(cat dnsHorizon) )
      #  rm dnsHorizon
      "${PWD}/certs/make_db_certs.bash" "${fullName}" ${dnsHorizon[@]}
      else
      "${PWD}/certs/make_db_certs.bash" "${fullName}"
    fi

    # Create a secret for the member certs for TLS
    # kubectl delete secret "mdb-${fullName}-cert" "mdb-${fullName}-cert-pem" > /dev/null 2>&1
    kubectl delete secret "mdb-${fullName}-cert" > /dev/null 2>&1
    kubectl create secret tls "mdb-${fullName}-cert" \
      --cert="${PWD}/certs/${fullName}.crt" \
      --key="${PWD}/certs/${fullName}.key"

    for ctype in agent clusterfile
    do   
      "${PWD}/certs/make_sharded_certs.bash" "${fullName}" ${ctype}
      # Create a secret for the member certs for TLS
      cert=""
      if [[ "${ctype}" == "agent" ]]
      then
      cert="-certs"
      fi
      kubectl delete secret "mdb-${fullName}-${ctype}${cert}" > /dev/null 2>&1
      kubectl create secret tls "mdb-${fullName}-${ctype}${cert}" \
          --cert="${PWD}/certs/${fullName}-${ctype}.crt" \
          --key="${PWD}/certs/${fullName}-${ctype}.key"
    done

      # Create a map for the cert
      kubectl delete configmap ca-pem > /dev/null 2>&1
      kubectl create configmap ca-pem \
          --from-file="ca-pem=${PWD}/certs/ca.pem"
  fi # end if sharded or replicaset
else
# no tls here
  if [[ $orgId != "" ]]
  then
    kubectl delete configmap "${fullName}" > /dev/null 2>&1
    kubectl create configmap "${fullName}" \
    --from-literal="orgId=${orgId}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="baseUrl=${opsMgrUrl}"
  else
    kubectl delete configmap "${fullName}" > /dev/null 2>&1
    kubectl create configmap "${fullName}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="baseUrl=${opsMgrUrl}"
  fi
fi # tls

# Create a a secret for a db user credentials
kubectl delete secret         ${fullName}-admin > /dev/null 2>&1
kubectl create secret generic ${fullName}-admin \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}"

# Create the User Resources
kubectl delete mdbu ${fullName}-admin > /dev/null 2>&1
kubectl apply -f "${mdbuser1}"

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  kubectl delete mdbu ${fullName}-ldap > /dev/null 2>&1
  kubectl apply -f "${mdbuser2}"
  kubectl delete secret         "${fullName}-ldapsecret" > /dev/null 2>&1
  kubectl create secret generic "${fullName}-ldapsecret" \
    --from-literal=password="${ldapBindQueryPassword}" 
fi

# remove any certificate requests
list=( $( kubectl get csr 2>/dev/null | grep "${fullName}" | awk '{print $1}' ) )
if [[ ${#list[@]} > 0 ]]
then
    kubectl delete csr ${list[@]} > /dev/null 2>&1
fi

# Create the DB Resource
kubectl apply -f "${mdb}"

# Monitor the progress
resource="mongodb/${fullName}"
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
cs=$( bin/get_connection_string.bash -n "${fullName}" )
if [[ "$cs" == *external* ]]
then
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect directly by running: bin/connect_external.bash -n \"${fullName}\""
    printf "%s\n" "                      or connect from the pod by running: bin/connect_from_pod.bash -n \"${fullName}\""
else
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect from the pod by running: bin/connect_from_pod.bash -n \"${fullName}\""
fi
exit 0
