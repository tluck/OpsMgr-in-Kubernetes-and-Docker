#!/bin/bash

source init.conf

while getopts 'n:h' opt
do
  case "$opt" in
    n) name="$OPTARG" ;;
    ?|h)
      echo "Usage: $(basename $0) [-n clusterName] "
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

name=${name:-myproject1-myreplicaset}
export PATH=.:bin:$PATH

cs=$( get_connection_string.bash -n "${name}" )
fcs=${cs#*:}
printf "\n%s\n\n" "Connection String: ${fcs}"
eval "mongosh ${fcs}"
