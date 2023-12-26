#!/bin/bash

while getopts 'n:s:h' opts
do
  case "$opts" in
    n) name="$OPTARG" ;;
    s) sName="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) -n name "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-mymulticlusterproject-myreplicaset}
#[[ "${name}" == "" ]] && exit 1

source init.conf
TAB=$'\t'
#iplist=( $( get_iplist.bash -n "${name}" ) )
#[[ $? != 0 ]] && exit 1

mdbKind=mdbmc
#eval externalDomain=$( kubectl get mdbmc ${name} -o json | jq .spec.externalAccess.externalDomain ); 
eval domainList=( $(kubectl -n ${mcNamespace} get ${mdbKind} ${name} -o json|jq .spec.clusterSpecList[].externalAccess.externalDomain ) )
eval dnszone=$( gcloud dns managed-zones list --format json | jq .[].name )

eval iplist[0]=$( kubectl --context=$MDB_CLUSTER_0_CONTEXT -n ${mcNamespace} get svc ${name}-0-0-svc-external  -o json |jq .status.loadBalancer.ingress[].ip )
eval iplist[1]=$( kubectl --context=$MDB_CLUSTER_0_CONTEXT -n ${mcNamespace} get svc ${name}-0-1-svc-external  -o json |jq .status.loadBalancer.ingress[].ip )
eval iplist[2]=$( kubectl --context=$MDB_CLUSTER_1_CONTEXT -n ${mcNamespace} get svc ${name}-1-0-svc-external  -o json |jq .status.loadBalancer.ingress[].ip )
eval iplist[3]=$( kubectl --context=$MDB_CLUSTER_1_CONTEXT -n ${mcNamespace} get svc ${name}-1-1-svc-external  -o json |jq .status.loadBalancer.ingress[].ip )
eval iplist[4]=$( kubectl --context=$MDB_CLUSTER_2_CONTEXT -n ${mcNamespace} get svc ${name}-2-0-svc-external  -o json |jq .status.loadBalancer.ingress[].ip )

gcloud dns --project=${MDB_GKE_PROJECT} record-sets delete ${name}-0-0.${domainList[0]} --type="A" --zone="${dnszone}" > /dev/null 2>&1
gcloud dns --project=${MDB_GKE_PROJECT} record-sets delete ${name}-0-1.${domainList[0]} --type="A" --zone="${dnszone}" > /dev/null 2>&1
gcloud dns --project=${MDB_GKE_PROJECT} record-sets delete ${name}-1-0.${domainList[1]} --type="A" --zone="${dnszone}" > /dev/null 2>&1
gcloud dns --project=${MDB_GKE_PROJECT} record-sets delete ${name}-1-1.${domainList[1]} --type="A" --zone="${dnszone}" > /dev/null 2>&1
gcloud dns --project=${MDB_GKE_PROJECT} record-sets delete ${name}-2-0.${domainList[2]} --type="A" --zone="${dnszone}" > /dev/null 2>&1

gcloud dns --project=${MDB_GKE_PROJECT} record-sets create ${name}-0-0.${domainList[0]} --type="A" --zone="${dnszone}" --rrdatas="${iplist[0]}" --ttl="300"
gcloud dns --project=${MDB_GKE_PROJECT} record-sets create ${name}-0-1.${domainList[0]} --type="A" --zone="${dnszone}" --rrdatas="${iplist[1]}" --ttl="300"
gcloud dns --project=${MDB_GKE_PROJECT} record-sets create ${name}-1-0.${domainList[1]} --type="A" --zone="${dnszone}" --rrdatas="${iplist[2]}" --ttl="300"
gcloud dns --project=${MDB_GKE_PROJECT} record-sets create ${name}-1-1.${domainList[1]} --type="A" --zone="${dnszone}" --rrdatas="${iplist[3]}" --ttl="300"
gcloud dns --project=${MDB_GKE_PROJECT} record-sets create ${name}-2-0.${domainList[2]} --type="A" --zone="${dnszone}" --rrdatas="${iplist[4]}" --ttl="300"

eval domainList=( $(kubectl -n ${mcNamespace} get ${mdbKind} ${name} -o json|jq .spec.clusterSpecList[].externalAccess.externalDomain ) )

names=(     "${name}-0-0" \
            "${name}-0-1" \
            "${name}-1-0" \
            "${name}-1-1" \
            "${name}-2-0" )

fullNames=( "${name}-0-0.${domainList[0]}" \
            "${name}-0-1.${domainList[0]}" \
            "${name}-1-0.${domainList[1]}" \
            "${name}-1-1.${domainList[1]}" \
            "${name}-2-0.${domainList[2]}" )

num=${#iplist[@]}
# if [[ ${num} > 0 ]]
# then
#     num=$(( $num-1 ))
# else
#     exit 1
# fi

printf "\n" 
n=0
while [ $n -lt $num ]
do
  m=$n;  if [[ $m > $num ]]; then m=$num; fi;
  grep "^[0-9].*${names[$n]}" /etc/hosts > /dev/null 2>&1
  if [[ $? == 0 ]]
  then
    # replace host entry
    printf "%s" "Replacing /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${fullNames[$n]}" 
    sudo ${sed} -E -e      "s|^[0-9].*${names[$n]}.*|${iplist[$m]}${TAB}${names[$n]} ${fullNames[$n]}|" /etc/hosts 
  else
    # add host entry
    printf "%s" "Adding /etc/hosts entry: "
    printf "%s\n"                                   "${iplist[$m]}${TAB}${names[$n]} ${fullNames[$n]}" | sudo tee -a /etc/hosts
  fi
n=$((n+1))
done

