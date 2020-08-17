#!/bin/bash

d=$( dirname "$0" )
curdir=$( pwd )
cd "${d}"/../k8s

Misc/create_key.bash
Misc/create_org.bash Demo
Misc/get_user_id.bash thomas.luckenbach@mongodb.com
Misc/add_user_to_org.bash Demo
Misc/create_project.bash Project1
Misc/create_project.bash Project2

source init.conf
mv *json ${curdir}

mmsGroupId=$Project1Id
mmsApiKey=$Project1agentApiKey
sed -i .bak  -E -e "s|(mmsGroupId=).*|\1${mmsGroupId}|"  ../Docker/3.2_node/data/automation-agent.config
sed -i .bak  -E -e "s|(mmsApiKey=).*|\1${mmsApiKey}|"    ../Docker/3.2_node/data/automation-agent.config

mmsGroupId=$Project2Id
mmsApiKey=$Project2agentApiKey
sed -i .bak  -E -e "s|(mmsGroupId=).*|\1${mmsGroupId}|"  ../Docker/4.x_node/data/automation-agent.config
sed -i .bak  -E -e "s|(mmsApiKey=).*|\1${mmsApiKey}|"    ../Docker/4.x_node/data/automation-agent.config
