#!/bin/bash 

source init.conf

org=${1:-DemoOrg}
project=${2:-DemoProject}
user=${3:-$user}

bin/create_key.bash
bin/create_org.bash "${org}"
bin/get_user_id.bash "$user"
bin/add_user_to_org.bash "${org}"
bin/create_project.bash "${project}"
