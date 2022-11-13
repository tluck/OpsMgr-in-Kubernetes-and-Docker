#!/bin/bash 

source init.conf

org=${1:-DemoOrg}
project=${2:-DemoProject}
user=${3:-$user}

Misc/create_key.bash
Misc/create_org.bash "${org}"
Misc/get_user_id.bash "$user"
Misc/add_user_to_org.bash "${org}"
Misc/create_project.bash "${project}"
