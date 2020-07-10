#!/bin/bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy the Operator ..."
deploy_Operator.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Deploy OM and wait until Running status..."
deploy_OM.bash

#printf "\n%s\n" "__________________________________________________________________________________________"
#printf "%s\n" "Create the first Org in OM ..."
#deploy_org.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the Backup Oplog1/BlockStore1 DB for OM ..."
deploy_OM_BackupDB.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Create the 1st Production DB ..."
deploy_ProdDB.bash

printf "\n%s\n" "__________________________________________________________________________________________"
printf "%s\n" "Update splitHorizon configuration for External access to Production DB ..."
deploy_ProdDB_splitHorizon.bash
