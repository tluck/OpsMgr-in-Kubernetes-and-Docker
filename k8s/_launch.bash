#!/bin/bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
deploy_OM.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the firt Org in OM ..."
deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1/BlockStore1 DB for OM ..."
deploy_OM_BackupDB.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the 1st Production DB ..."
deploy_ProdDB.bash
