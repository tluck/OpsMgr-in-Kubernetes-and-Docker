#/bin/bash

d=$( dirname "$0" )
cd "${d}"
source init.conf

while getopts 'n:c:m:d:v:l:ks:r:i:o:p:e:gxh' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    c) cpu="$OPTARG" ;;
    m) mem="$OPTARG" ;;
    d) dsk="$OPTARG" ;;
    v) ver="$OPTARG" ;;
    e) expose="$OPTARG" ;;
    l) ldap="$OPTARG" ;;
    k) kmip=true ;;
    o) orgName="$OPTARG";;
    p) projectName="$OPTARG";;
    g) makeCerts=false ;; 
    x) x=true ;; # cleanup
    s) shards="$OPTARG" ;;
    r) mongos="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n name] [-c cpu] [-m memory] [-d disk] [-v ver] [ -e horizon ] [-s shards] [-r mongos] [-l ldap[s]] [-k] [-o orgName] [-p projectName] [-g] [-x]"
      echo "Usage:       -e to generate the external service definitions when using externalDomain or splitHorizon names"
      echo "Usage:           - for replicaSets: use -e horizon or -e external.domain"
      echo "Usaag:           - for sharded clusters: use -e mongos"
      echo "Usage:       -g to NOT (re)create the certs."
      echo "Usage:       -x for a total clean up "
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
dbFcv="${ver%.*}"
mem="${mem:-2Gi}"
cpu="${cpu:-1.0}"
dsk="${dsk:-1Gi}"
cleanup=${x:-false}
projectName="${projectName:-$name}"
if [[ ${orgName} != "" ]]
then
    orgInfo=( $( get_org.bash -o ${orgName} ) )
    orgId=${orgInfo[1]}
fi
fullName=$( printf "${projectName}-${name}"| tr '[:upper:]' '[:lower:]' )
makeCerts=${makeCerts:-true}
[[ ${demo} ]] && serviceType="NodePort" clusterDomain="cluster.local"
duplicateServiceObjects=false

# make manifest from template
mdb="mdb_${fullName}.yaml"
mdbuser1="mdbuser_${fullName}_admin.yaml"
[[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]] && mdbuser2="mdbuser_${fullName}_ldap.yaml"

tlsc="#TLS "
tlsr=${tlsc}
[[ ${x509} == true ]] && x509m=', "X509"'
if [[ ${tls} == true ]]
then
    tlsr=""
else
    x509m="" # disable x509 if TLS is off
fi

sslRequireValidMMSServerCertificates=false
allowConnectionsWithoutCertificates=true
tlsMode=${tlsMode:-"requireTLS"}
if [[ ${tlsMode} == "requireTLS" ]]
then
    sslRequireValidMMSServerCertificates=true
    allowConnectionsWithoutCertificates=false
fi

kmipc="#KMIP "
kmipString=${kmipc}
[[ ${kmip} == true ]] && kmipString=""

ldapt="#LDAPT "
ldaptls="none"
ldapString="#LDAP  "
if [[ ${ldap} == 'ldaps' ]]
then
    ldapt=""
    ldaptls="tls"
    ldapm=', "LDAP"'
    ldapString=""
elif [[ ${ldap} == 'ldap' ]]
then
    ldapt="#LDAPT "
    ldaptls="none"
    ldapm=', "LDAP"'
    ldapString=""
fi

# multi-Cluster
unset multiCluster 
[[ $0 == *multi* ]] && export multiCluster=true 
multiClusterString="#MULTI "
mdbKind="MongoDB"
if [[ ${multiCluster} == true ]]
then
  multiClusterString=""
  clusterDomain="${multiClusterDomain}"
  mdbKind="MongoDBMultiCluster"
  multiClusterOption="-m"
  duplicateServiceObjects=true
  # recreate configmap and secret for OM in mcNamespace
  if [[ ${namespace} != ${mcNamespace} ]]
  then
  kubectl -n ${mcNamespace} get configmap ${omName}-ca  >/dev/null 2>&1
  if [[ $? != 0 ]] 
  then
    kubectl -n ${namespace} get configmap ${omName}-ca -o yaml \
    | sed "s|namespace: ${namespace}|namespace: ${mcNamespace}|" \
    | kubectl -n ${mcNamespace} apply -f -
  fi

  kubectl -n ${mcNamespace} get secret ${mcNamespace}-${omName}-admin-key >/dev/null 2>&1
  if [[ $? != 0 ]]
  then
    eval publicKey=$(  kubectl -n ${namespace} get secret ${namespace}-${omName}-admin-key -o jsonpath='{.data.publicKey}' | base64 -d )
    eval privateKey=$( kubectl -n ${namespace} get secret ${namespace}-${omName}-admin-key -o jsonpath='{.data.privateKey}' | base64 -d )
    kubectl -n ${mcNamespace} create secret generic ${mcNamespace}-${omName}-admin-key \
      --from-literal="publicKey=${publicKey}" \
      --from-literal="privateKey=${privateKey}"
  fi
  fi # diff namespace
  namespace=${mcNamespace}
fi # multicluster

# expose services
mcexposeString="#MCEXPOSE "
exposeString="#EXPOSE "
extdomainString="#EXTDOMAIN "
# externalDomain is a per MDB Cluster parameter
unset externalDomain
if [[ ${expose} ]] 
then 
  exposeString=""
  if [[ ${multiCluster} == true ]]
  then
    exposeString="#EXPOSE "
    mcexposeString="" 
    duplicateServiceObjects=true
  fi
  if [[ ${expose} != "horizon" ]] 
  then 
    exposeString=""
    export externalDomain="${expose}"
    extdomainString=""
    duplicateServiceObjects=false
  fi
fi

cat ${template} | sed \
  -e "s|MDBKIND|$mdbKind|" \
  -e "s|#EXPOSE |$exposeString|" \
  -e "s|#MCEXPOSE |$mcexposeString|" \
  -e "s|EXTDOMAINNAME|$externalDomain|" \
  -e "s|#EXTDOMAIN |$extdomainString|" \
  -e "s|CLUSTER0|$MDB_CLUSTER_0|" \
  -e "s|CLUSTER1|$MDB_CLUSTER_1|" \
  -e "s|CLUSTER2|$MDB_CLUSTER_2|" \
  -e "s|DOMAINNAME|$clusterDomain|" \
  -e "s|DUPSERVICE|$duplicateServiceObjects|" \
  -e "s|$tlsc|$tlsr|" \
  -e "s|TLSMODE|$tlsMode|" \
  -e "s|ALLOWCON|$allowConnectionsWithoutCertificates|" \
  -e "s|$kmipc|$kmipString|" \
  -e "s|VERSION|$ver|" \
  -e "s|FCV|$dbFcv|" \
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
  -e "s|OPSMANAGER|$omName|" \
  -e "s|SERVICETYPE|$serviceType|" \
  -e "s|X509M|$x509m|" \
  -e "s|LDAPM|$ldapm|" \
  -e "s|#LDAP  |$ldapString|" \
  -e "s|#LDAPT |$ldapt|" \
  -e "s|LDAPTLS|$ldaptls|" \
  -e "s|LDAPBINDQUERYUSER|$ldapBindQueryUser|" \
  -e "s|LDAPAUTHZQUERYTEMPLATE|$ldapAuthzQueryTemplate|" \
  -e "s|LDAPUSERTODNMAPPING|$ldapUserToDNMapping|" \
  -e "s|LDAPTIMEOUTMS|$ldapTimeoutMS|" \
  -e "s|LDAPUSERCACHEINVALIDATIONINTERVAL|$ldapUserCacheInvalidationInterval|" \
  -e "s|LDAPSERVER|$ldapServer|" \
  -e "s|LDAPCERTMAPNAME|$ldapCertMapName|" \
  -e "s|LDAPKEY|$ldapKey|" \
  -e "s|#MULTI |$multiClusterString|" \
  -e "s|MDB_CLUSTER_0_CONTEXT|$MDB_CLUSTER_0_CONTEXT|" \
  -e "s|MDB_CLUSTER_1_CONTEXT|$MDB_CLUSTER_1_CONTEXT|" \
  -e "s|MDB_CLUSTER_2_CONTEXT|$MDB_CLUSTER_2_CONTEXT|" \
  -e "s|PROJECT-NAME|$fullName|" > "$mdb"

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
if [[ ${cleanup} == true ]]
then
  printf "Cleaning up ... \n"
  kubectl -n ${namespace} delete ${mdbKind} "${fullName}" --now > /dev/null 2>&1
  for type in sts pods svc secrets configmaps pvc mdbu
  do
    kubectl -n ${namespace} delete $( kubectl -n ${namespace} get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1
    if [[ ${multiCluster} == true ]]
    then
      kubectl -n ${namespace} --context=$MDB_CLUSTER_0_CONTEXT -n $namespace delete $( kubectl -n ${namespace} --context=$MDB_CLUSTER_0_CONTEXT -n $namespace get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1 
      kubectl -n ${namespace} --context=$MDB_CLUSTER_1_CONTEXT -n $namespace delete $( kubectl -n ${namespace} --context=$MDB_CLUSTER_1_CONTEXT -n $namespace get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1 
      kubectl -n ${namespace} --context=$MDB_CLUSTER_2_CONTEXT -n $namespace delete $( kubectl -n ${namespace} --context=$MDB_CLUSTER_2_CONTEXT -n $namespace get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1 
    fi
  done
  if [[ ${tls} == true ]]
  then
  for type in csr certificaterequests certificates secrets
  do
    kubectl -n ${namespace} delete $( kubectl -n ${namespace} get $type -o name | grep "${fullName}" ) --now > /dev/null 2>&1
  done
  fi
  delete_project.bash -p ${projectName} 
  printf "... Done.\n"
  exit
fi

# Create map for OM Org/Project
printf "Using Ops Manager at: ${opsMgrUrl} \n"
printf "%s\n" "Deploying cluster: ${fullName}, version: ${mdbVersion}, cores: ${cpu}, memory: ${mem}, disk: ${dsk}" 
[[ ${shards} ]] && printf "%s\n" "    shards: ${shards}, mongos: ${mongos}"
printf "%s\n" "    in org: ${deploymentOrgName}, project: ${projectName} with: expose: ${expose}, LDAP: ${ldapType}"
printf "\n"

if [[ ${tls} == true ]]
then
  kubectl -n ${namespace} delete configmap "${fullName}" > /dev/null 2>&1
  kubectl -n ${namespace} create configmap "${fullName}" \
        --from-literal="baseUrl=${opsMgrUrl}" \
        --from-literal="orgId=${orgId}" \
        --from-literal="projectName=${projectName}" \
        --from-literal="sslMMSCAConfigMap=${omName}-ca" \
        --from-literal="sslRequireValidMMSServerCertificates=${sslRequireValidMMSServerCertificates}" 2> /dev/null

  if [[ ${sharded} == true ]]
  then
    if [[ ${makeCerts} == true ]]
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
      kubectl -n ${namespace} apply -f "${PWD}/certs/certs_mdb-${fullName}-${ctype}${cert}.yaml"
      done
    fi
  else 
    # ReplicaSet
    # create new certs if the service does not exist
    if [[ ${makeCerts} == true ]]
    then
      kubectl -n ${namespace} delete secret mdb-${fullName}-cert > /dev/null 2>&1
      "${PWD}/certs/make_cluster_certs.bash" "${fullName}"
      kubectl -n ${namespace} apply -f "${PWD}/certs/certs_mdb-${fullName}-cert.yaml"

      ctype="agent"
      cert="-certs"
      kubectl -n ${namespace} delete secret mdb-${fullName}-${ctype}${cert} > /dev/null 2>&1
      "${PWD}/certs/make_sharded_certs.bash" "${fullName}" ${ctype} ${cert}
      kubectl -n ${namespace} apply -f "${PWD}/certs/certs_mdb-${fullName}-${ctype}${cert}.yaml"
    fi
  fi # end if sharded or replicaset

else
# no tls here
    kubectl -n ${namespace} delete configmap "${fullName}" > /dev/null 2>&1
    kubectl -n ${namespace} create configmap "${fullName}" \
    --from-literal="orgId=${orgId}" \
    --from-literal="projectName=${projectName}" \
    --from-literal="baseUrl=${opsMgrUrl}" 2> /dev/null
fi # tls

# create secrets and config map for KMIP server
if [[ ${kmip} == true ]] 
then
    kubectl -n ${namespace} delete configmap ${fullName}-kmip-ca-pem >/dev/null 2>&1
    kubectl -n ${namespace} create configmap ${fullName}-kmip-ca-pem --from-file="ca.pem=certs/kmip_ca.pem"
    kubectl -n ${namespace} delete secret generic ${fullName}-kmip-client-pem >/dev/null 2>&1
    kubectl -n ${namespace} create secret generic ${fullName}-kmip-client-pem --from-file="cert.pem=certs/kmip_cert.pem"
fi

# Create a a secret for a db user credentials
kubectl -n ${namespace} delete secret         ${fullName}-admin > /dev/null 2>&1
kubectl -n ${namespace} create secret generic ${fullName}-admin \
    --from-literal=name="${dbuser}" \
    --from-literal=password="${dbpassword}" 2> /dev/null

# Create the User Resources
kubectl -n ${namespace} delete mdbu ${fullName}-admin > /dev/null 2>&1
kubectl -n ${namespace} apply -f "${mdbuser1}" 2> /dev/null

if [[ ${ldap} == 'ldap' || ${ldap} == 'ldaps' ]]
then
  kubectl -n ${namespace} delete mdbu ${fullName}-ldap > /dev/null 2>&1
  kubectl -n ${namespace} apply -f "${mdbuser2}"
  kubectl -n ${namespace} delete secret "${fullName}-ldapsecret" > /dev/null 2>&1
  kubectl -n ${namespace} create secret generic "${fullName}-ldapsecret" \
    --from-literal=password="${ldapBindQueryPassword}" 2> /dev/null 
fi

# Create the DB Resource
kubectl -n ${namespace} apply -f "${mdb}"
# for SplitHorizons - append horizons and reissue certs with horizons
sleep 3
if [[ ${expose} && ${sharded} == false ]] 
then
  printf "%s\n" "Generating ${serviceType} Service ports ..."
  serviceOut=$( expose_service.bash -n "${fullName}" -g ${makeCerts} ${multiClusterOption} ) 
  if [[ $? != 0 ]]
  then 
    printf "* * * Error - Failed to get services.\n"
    exit 1
  fi
  nlines=5
  [[ ${multiCluster} ]] && nlines=9
  printf "${serviceOut}\n"| head -n ${nlines}
  if [[ ${externalDomain} ]]
  then
    printf "\nMake sure external DNS is configured for your replicaSet\n"
    printf "  - Match repSet names to the service External-IP\n"
    if [[ ! ${multiCluster} || ${multiCluster} == false ]] 
    then
      printf "  - The repSet names are : ${fullName}-[012].${externalDomain}\n"
      update_dns.bash -n "${fullName}"
    else
    #if [[ ${multiCluster} == true ]]
    #then
      printf "  - The repSet names are in the form: ${fullName}-0-[012].${MDB_CLUSTER_0}.${externalDomain}\n"
      printf "  - The repSet names are in the form: ${fullName}-1-[012].${MDB_CLUSTER_1}.${externalDomain}\n"
      printf "  - The repSet names are in the form: ${fullName}-2-[012].${MDB_CLUSTER_2}.${externalDomain}\n"
      update_mc_dns.bash -n "${fullName}"
    fi
  else
    kubectl -n ${namespace} apply -f "${mdb}" # re-apply for splitHorizon addition
    printf "\nAdded this configuration to the manifest ${mdb}:\n" 
    eval tail -n 5 "${mdb}"
  fi
  printf "... Done.\n"
fi

# remove any certificate requests
if [[ ${tls} == true ]]
then
  kubectl -n ${namespace} delete csr $( kubectl -n ${namespace} get csr -o name | grep "${fullName}" ) > /dev/null 2>&1
  kubectl -n ${namespace} delete certificaterequest $( kubectl -n ${namespace} get certificaterequest -o name | grep "${fullName}" ) > /dev/null 2>&1
fi

# Monitor the progress
resource="${mdbKind}/${fullName}"
printf "\n%s\n" "Monitoring the progress of resource ${resource} ..."
notapproved="Not all certificates have been approved"
certificate="Certificate"
n=0
max=80
while [ $n -lt $max ]
do
    kubectl -n ${namespace} get "${resource}"
    pstatus=$( kubectl -n ${namespace} get "${resource}" -o jsonpath={'.status.phase'} )
    message=$( kubectl -n ${namespace} get "${resource}" -o jsonpath={'.status.message'} )
    printf "%s\n" "status.message: $message"
    # if [[ "${message:0:39}" == "${notapproved}" ||  "${message:0:11}" == "${certificate}" ]]
    # then
    #     # TLS Cert approval (if using autogenerated certs -- deprecated)
    #     kubectl -n ${namespace} certificate approve $( kubectl -n ${namespace} get csr | grep "Pending" | awk '{print $1}' )
    # fi
    #if [[ "$pstatus" == "Pending" || "$pstatus" == "Running" ]];
    if [[ "$pstatus" == "Running" ]];
    then
        printf "Status: %s\n" "$pstatus"
        break
    fi
    sleep 15
    n=$((n+1))
done

sleep 5
printf "\n"
cs=$( get_connection_string.bash -n "${fullName}" ${multiClusterOption} )
if [[ "$cs" == *external* ]]
then
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect directly by running: connect_external.bash -n \"${fullName}\" ${multiClusterOption}"
    printf "%s\n" "                      or connect from the pod by running: connect_from_pod.bash -n \"${fullName}\" ${multiClusterOption}"
else
    printf "\n%s\n\n" "$cs"
    printf "%s\n" "To see if access is working, connect from the pod by running: connect_from_pod.bash -n \"${fullName}\" ${multiClusterOption}"
fi
exit 0
