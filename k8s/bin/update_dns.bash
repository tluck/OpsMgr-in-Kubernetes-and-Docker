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

source init.conf
ips=( $( get_ips.bash -n "${name}" ) )
[[ $? != 0 ]] && exit 1

eval externalDomain=$( kubectl get mdb ${name} -o json | jq .spec.externalAccess.externalDomain ); 
eval dnszone=$( gcloud dns managed-zones list --format json | jq .[].name )

# 3 nodes
for n in 0 1 2
do

gcloud dns --project=sa-na-west record-sets update ${name}-${n}.${externalDomain}  --type="A" --zone="${dnszone}" --rrdatas="${ips[$n]}" --ttl="300"

done
