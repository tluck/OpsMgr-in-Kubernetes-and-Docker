#!/bin/bash

source ./init.conf

name=${1:-myreplicaset}
export PATH=.:Misc:$PATH

fcs=$( get_connection_string.bash "${name}" )
printf "\n%s\n\n" "Connect String: ${fcs}"
eval "mongosh ${fcs}"
#eval cs=\$${name//-/}_URI
#fcs=\'${cs}${ssltls_enabled}\'
#eval "mongo ${fcs} ${ssltls_options}"
