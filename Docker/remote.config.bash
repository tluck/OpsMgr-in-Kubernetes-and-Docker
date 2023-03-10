#!/bin/bash

#echo "${1} 	opsmanager-svc.mongodb.svc.cluster.local opsmgr" >>/etc/hosts
TAB=$'\t'
cat /etc/hosts | sed -e "/opsmanager-svc.mongodb.svc.cluster.local/d" > /tmp/hosts
sudo mv /tmp/hosts /etc/hosts
printf "%s\n" "${1}${TAB}opsmanager-svc.mongodb.svc.cluster.local" | sudo tee -a /etc/hosts
cat /etc/hosts

sudo systemctl stop mongodb-mms-automation-agent.service
sudo kill -9 $( ps -f  -u mongod| grep -v UID |awk '{print $2}' )
if [[ -d /data ]]
then
sudo rm -rf /data/*
else
sudo mkdir /data
sudo mkdir /etc/mongodb-mms/
fi
sudo cp ca-pem                  /etc/mongodb-mms/ca.pem
sudo cp automation-agent.config /etc/mongodb-mms/
sudo chmod 600 /etc/mongodb-mms/ca.pem
if [[ ! -e mongodb-mms-automation-agent-manager-10.2.19.5989-1.x86_64.rhel7.rpm ]]
then
sudo curl -OL https://opsmanager-svc.mongodb.svc.cluster.local:8443/download/agent/automation/mongodb-mms-automation-agent-manager-10.2.19.5989-1.x86_64.rhel7.rpm  --cacert /etc/mongodb-mms/ca.pem 
fi
sudo rpm -i mongodb-mms-automation-agent-manager-10.2.19.5989-1.x86_64.rhel7.rpm 
sudo chown mongod:mongod /data /etc/mongodb-mms/*
sudo systemctl start mongodb-mms-automation-agent.service
