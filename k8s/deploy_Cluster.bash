#/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:l:s:r:i:o:p:egxh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    e) expose=true ;;
    l) ldap="$OPTARG" ;;
    i|o) orgId="$OPTARG";;
    p) projectName="$OPTARG";;
    g) skipMakeCerts=1 ;; 
    x) x=1 ;; # cleanup
    s) shards="$OPTARG" ;;
    r) mongos="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-v ver] [ -e ] [-s shards] [-r mongos] [-l ldap[s]] [-o orgId] [-p projectName] [-g] [-x]"
      echo "Usage:       -e to generate the splitHorizon configuration for the Replica Set"
      echo "Usage:       -x for total clean up before (re)deployment"
      echo "Usage:       -g to not recreate the certs."
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [[ $shards != "" || $mongos != "" ]]
then
    sharded=true
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
    sharded=false
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
tlsr=${tlsc}
[[ ${x509} == true ]] && x509m=', "X509"'
if [[ ${tls} == true ]]
then
    tlsr=""
else
    x509m=""
fi

sslRequireValidMMSServerCertificates=false
tlsMode=${tlsMode:-"requireTLS"}
if [[ ${tlsMode} == "requireTLS" ]]
then
    sslRequireValidMMSServerCertificates=true
fi

kmipc="#KMIP "
kmipr=${kmipc}
if [[ ${kmip} == true ]]
then
    kmipr=""
fi

ldapt="#LDAPT "
ldaptls="none"
if [[ ${ldap} == 'ldaps' ]]
then
    ldapt=""
    ldaptls="tls"
    ldapm=', "LDAP"'
elif [[ ${ldap} == 'ldap' ]]
then
    ldapt="#LDAPT "
    ldaptls="none"
    ldapm=', "LDAP"'
fi

if [[ ${tls} == 'true' ]]
then
  cat ${template} | sed \
    -e "s|$tlsc|$tlsr|" \
    -e "s|TLSMODE|$tlsMode|" \
    -e "s|$kmipc|$kmipr|" \
    -e "s|VERSION|$ver|" \
    -e "s|DOMAINNAME|$domainName|" \
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
    -e "s|SERVICETYPE|$serviceType|" \
    -e "s|X509M|$x509m|" \
    -e "s|LDAPM|$ldapm|" \
    -e "s|#LDAP  ||" \
    -e "s|#LDAPT |$lpapt|" \
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
    -e "s|$kmipc|$kmipr|" \
    -e "s|VERSION|$ver|" \
    -e "s|DOMAINNAME|$domainName|" \
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
    -e "s|SERVICETYPE|$serviceType|" \
    -e "s|X509M|$x509m|" \
    -e "s|LDAPM|$ldapm|" \
    -e "s|#LDAP  ||" \
    -e "s|#LDAPT |$lpapt|" \
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

# clean up old stuff
if [[ ${cleanup} == 1 ]]
then
  kubectl delete mdb "${fullName}" --now > /dev/null 2>&1
  kubectl delete $( kubectl get pods -o name | grep "${fullName}" ) --force --now > /dev/null 2>&1
  for type in pvc svc secrets configmaps
  do
    kubectl delete $( kubectl get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1
  done
  if [[ ${tls} == true ]]
  then
  for type in csr certificaterequests certificates
  do
    kubectl delete $( kubectl get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1
  done
  fi
fi

# Create map for OM Org/Project
if [[ ${tls} == true ]]
then
  [[ ${cleanup} == 1 ]] && kubectl delete configmap "${fullName}" > /dev/null 2>&1
  if [[ $orgId != "" ]]
  then
    kubectl create configmap "${fullName}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="orgId=${orgId}" \
        --from-literal="projectName=${projectName}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates=${sslRequireValidMMSServerCertificates}" 2> /dev/null
  else
    kubectl create configmap "${fullName}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="orgId=" \
        --from-literal="projectName=${projectName}" \
        --from-literal="sslMMSCAConfigMap=opsmanager-ca" \
        --from-literal="sslRequireValidMMSServerCertificates=${sslRequireValidMMSServerCertificates}" 2> /dev/null
  fi

  if [[ ${sharded} == true ]]
  then
    if [[ ${skipMakeCerts} == 0 ]]
    then 
      # mdb-{metadata.name}-mongos-cert
      # mdb-{metadata.name}-config-cert
      # mdb-{metadata.name}-<x>-cert x=0,1 (2 shards)
      for ctype in agent mongos config $( seq -s " " 0 $(( $shards-1)) )
      do   
      # Create a secret for the member certs for TLS
      cert="-cert"
      [[ "${ctype}" == "agent" ]] && cert="-certs"
      "${PWD}/certs/make_sharded_certs.bash" "${fullName}" ${ctype} ${cert}
      kubectl apply -f "${PWD}/certs/certs_mdb-${fullName}-${ctype}${cert}.yaml"
      done
    fi
  else 
    # ReplicaSet
    # create new certs if the service does not exist
    # check to see if the external svc needs to be created
    if [[ $expose == true && ${sharded} == false ]] 
    then
        printf "%s\n" "Generating ${serviceType} Service ports..."
        serviceOut=$( expose_service.bash "${mdb}" ) 
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
    
    # now make the certs
    if [[ ${skipMakeCerts} == 0 ]]
    then
    if [[ ${#dnsHorizon[@]} != 0  ]] 
    then
      "${PWD}/certs/make_cluster_certs.bash" "${fullName}" ${dnsHorizon[@]}
      else
      "${PWD}/certs/make_cluster_certs.bash" "${fullName}"
    fi
    kubectl apply -f "${PWD}/certs/certs_mdb-${fullName}-cert.yaml"
    fi
  fi # end if sharded or replicaset

else
# no tls here
  [[ ${cleanup} == 1 ]] && kubectl delete configmap "${fullName}" > /dev/null 2>&1
  if [[ $orgId != "" ]]
  then
    kubectl create configmap "${fullName}" \
    --from-literal="orgId=${orgId}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="baseUrl=${opsMgrUrl}" 2> /dev/null
  else
    kubectl create configmap "${fullName}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="baseUrl=${opsMgrUrl}" 2> /dev/null
  fi
fi # tls

# Create a a secret for a db user credentials
[[ ${cleanup} == 1 ]] && kubectl delete secret         ${fullName}-admin > /dev/null 2>&1
kubectl create secret generic ${fullName}-admin \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}" 2> /dev/null

# Create the User Resources
[[ ${cleanup} == 1 ]] && kubectl delete mdbu ${fullName}-admin > /dev/null 2>&1
kubectl apply -f "${mdbuser1}" 2> /dev/null

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  [[ ${cleanup} == 1 ]] && kubectl delete mdbu ${fullName}-ldap > /dev/null 2>&1
  kubectl apply -f "${mdbuser2}"
  [[ ${cleanup} == 1 ]] && kubectl delete secret "${fullName}-ldapsecret" > /dev/null 2>&1
  kubectl create secret generic "${fullName}-ldapsecret" \
    --from-literal=password="${ldapBindQueryPassword}" 2> /dev/null 
fi

# Create the DB Resource
kubectl apply -f "${mdb}"

# remove any certificate requests
if [[ ${tls} == true ]]
then
  kubectl delete csr $( kubectl get csr -o name | grep "${fullName}" ) > /dev/null 2>&1
  kubectl delete certificaterequest $( kubectl get certificaterequest -o name | grep "${fullName}" ) > /dev/null 2>&1
fi

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
    # if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    # then
    #     # TLS Cert approval (if using autogenerated certs -- deprecated)
    #     kubectl certificate approve $( kubectl get csr | grep "Pending" | awk '{print $1}' )
    # fi
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
cs=$( get_connection_string.bash -n "${fullName}" )
if [[ "$cs" == *external* ]]
then
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect directly by running: connect_external.bash -n \"${fullName}\""
    printf "%s\n" "                      or connect from the pod by running: connect_from_pod.bash -n \"${fullName}\""
else
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect from the pod by running: connect_from_pod.bash -n \"${fullName}\""
fi
exit 0
