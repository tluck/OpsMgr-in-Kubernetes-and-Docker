#!/bin/bash

d=$( dirname "$0" )
mydir=$( pwd )

cd "${mydir}"/../k8s
source init.conf

# create Demo Org and 2 projects
orgName="Demo"
bin/get_key.bash
bin/create_org.bash -o ${orgName}
source custom.conf
# user can be supplied or is in init.conf
# add user to the org (orgId is in custom.conf)
orgId="${orgName}_orgId"
orgId="${!orgId}"
bin/add_user_to_org.bash -u "${user}" -i "${orgId}"

bin/create_project.bash -p Project1 -i "${orgId}"
bin/create_project.bash -p Project2 -i "${orgId}"

source init.conf
source custom.conf

mmsGroupId=${Project1_Id}
mmsApiKey=${Project1_agentApiKey}
sed -i .bak -E \
    -e "s|(mmsGroupId=).*|\1${mmsGroupId}|" \
    -e "s|(mmsApiKey=).*|\1${mmsApiKey}|"   \
    -e "s|(mmsBaseUrl=).*|\1${opsMgrUrl}|"  \
    ../Docker/6.x_node/data/automation-agent.config

mmsGroupId=${Project2_Id}
mmsApiKey=${Project2_agentApiKey}
sed -i .bak -E \
    -e "s|(mmsGroupId=).*|\1${mmsGroupId}|" \
    -e "s|(mmsApiKey=).*|\1${mmsApiKey}|"   \
    -e "s|(mmsBaseUrl=).*|\1${opsMgrUrl}|"  \
    ../Docker/5.x_node/data/automation-agent.config

# k8s nodes - build a RS with agents enabled in Project1
cd "${mydir}"/6.x_node
./deploy_nodes.bash -p Project1

# k8s nodes in Project2
cd "${mydir}"/5.x_node
./deploy_nodes.bash -p Project2
exit

# use cluster nodes to add servers to Project2
cd "$mydir"
source ../k8s/init.conf

nodes=( $( kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalDNS")].address}' ) )

cat Docker/4.x_node/data/automation-agent.config|sed -e "s?/shareddata?/etc/mongodb-mms?" > automation-agent.config 

for h in ${nodes[@]}
do 
scp -i ~/.ssh/tluck-aws-us-west-2.private.pem k8s/certs/ca-pem remote.config.bash automation-agent.config ec2-user@${h}:  
ssh -i ~/.ssh/tluck-aws-us-west-2.private.pem ec2-user@${h} sudo ./remote.config.bash ${opsMgrExtIp}
done

exit

