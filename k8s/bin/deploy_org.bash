#!/bin/bash 

# creates custom.conf with the out from below
source init.conf

orgName=${1:-myOrg}
user=${2:-$user} # comes from init.conf if not provided

#bin/create_key.bash
bin/get_key.bash
bin/create_org.bash -o "${orgName}"
bin/get_user_id.bash "${user}"
bin/add_user_to_org.bash "${orgName}"
#cat custom.conf
