#!/bin/bash

while getopts 'n:b:h' opt
do
  case "$opt" in
    n) fullName="$OPTARG" ;; 
    b) path="$OPTARG" ;; 
    ?|h)
      echo "Usage: $(basename $0) -n fullName -b <path to snapshot tar.gz> [-h]"
      exit 1
      ;;
  esac
done

fullName="${fullName:-myproject1-myreplicaset}"
path="${path:-/opt/Temp/backup/restore-655693ae28154a0de31ae11f.tar.gz}"
backup=${path##*/}
backupName="${backup%%.*}"

for i in 0 1 2
do 
    printf "Restoring ${fullName}-${i}:/data\n"
    kubectl cp ${path} ${fullName}-${i}:/data -c mongodb-enterprise-database
    kubectl exec ${fullName}-${i} -i -t -c mongodb-enterprise-database  -- bash -c 'rm -rf /data/[A-Z,b-q,s-z,_]*'
    kubectl exec ${fullName}-${i} -i -t -c mongodb-enterprise-database  -- bash -c "tar -C /data -zxf /data/${backup}"
    kubectl exec ${fullName}-${i} -i -t -c mongodb-enterprise-database  -- bash -c "mv /data/${backupName}/* /data"
    #kubectl exec ${fullName}-${i} -i -t -c mongodb-enterprise-database  -- bash -c "ls /data/${backupName}/ /data"
done
