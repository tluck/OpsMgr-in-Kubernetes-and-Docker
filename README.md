# OpsMgr Docker and K8s Demo
Ops Manager Demo Environment (in Docker)

GitHub Repo: 			https://github.com/tluck/OpsMgrDocker
Docker Image Repo: 	https://hub.docker.com/repository/docker/tjluckenbach/mongodb

## For Docker Summary:
Runs OpsManager 4.3 with severval agent-ready "empty nodes" to demo Automation and Backup

### Step 1. StartUp OpsMgr
- Build or pull the image
- Run the opsmgr_4.2 image
- Will create network mongo and install OpsMgr 4.3 and Backing DB Mongodb 4.2

### Step 2. Configure OpsMgr
- Add host alias to 127.0.0.1 localhost as OpsMgr in /etc/hosts
- Login and configure OpsMgr 
  - Set the server to http://opsmgr:8080
  - Use a fake mail server, smtp, port 25, and use defaults for other values
  - Click on Admin to et up Backup DB blockstore (localhost:27017)

### Step 3. Configure the Agent
- In OpsMgr in the Server function, create an API key
- Add the Group and API key to the file 4.2_node/data/automation-agent.config

### Step 4. Run nodes
- Wait for opsmgr to start
- Build/Run the node_4.2 image
- For 3 nodes: 
    - run these commands: run 1; run 2; run 3

### Step 5.
- Provision a cluster on the nodes


## For Kubernetes Summary:

### Step 1. Run the _launch.bash script
- Deploy  the K8s Operator
  - Then deploys the resources
- Deploy the OM Resources 
  -  OpsManager
  -  App DB
- Deploy a Production DB (on down rev DB)
- Deploy the OM Backing DBs