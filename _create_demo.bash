#!/bin/bash

d=$( dirname "$0" )
curdir=$( pwd )

cd "${curdir}"/k8s

# create Demo Org and 2 projects
Misc/create_key.bash
Misc/create_org.bash Demo
Misc/get_user_id.bash thomas.luckenbach@mongodb.com
Misc/add_user_to_org.bash Demo

Misc/create_project.bash Project1
mv project.json project1.json
Misc/create_project.bash Project2
mv project.json project2.json

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

# k8s nodes - build a 3.2 RS with agents enabled in Project1
cd ${curdir}/Docker/3.2_node
./deploy_nodes.bash

# k8s nodes in Project2
cd ${curdir}/Docker/4.x_node
./deploy_nodes.bash

# use cluster nodes to add servers to Project2
cd $curdir
source k8s/init.conf

nodes=( $( kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )

cat Docker/4.x_node/data/automation-agent.config|sed -e "s?/shareddata?/etc/mongodb-mms?" > automation-agent.config 

for h in ${nodes[@]}
do 
scp -i ~/.ssh/tluck-aws-us-west-2.private.pem k8s/certs/ca-pem remote.config.bash automation-agent.config ec2-user@${h}:  
ssh -i ~/.ssh/tluck-aws-us-west-2.private.pem ec2-user@${h} sudo ./remote.config.bash ${opsMgrExtIp}
done

exit

