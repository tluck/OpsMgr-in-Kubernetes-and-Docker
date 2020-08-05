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
- Login in to opsmgr:8080
- Provision a cluster on the 3 nodes


## For Kubernetes Summary:

### Step 1. Configure K8s with Docker Desktop
- Preference setup:
	* Kubernetes - Check Enable Kubernetes
	* Reources/Advanced: 
		* Configure 8 Cores
		* Configure 10GB of Memory
		* Configure 1GB of swap
		* Disk Image size (~30GB)
		
- Restart to enable new settings

### Step 2. Launch the Services
the _launch.bash script has serveral sections:

- Script 1: deploy_Operator.bash - Setup the OM enviroment
	- Defines the name space
	- Deploys the Mongodb Enterprise K8s Operator

- Script 2: deploy_Operator.bash - Setup the OM enviroment
  	- Deploy the OM Resources
  		- OpsManager
  		- App DB 
  	- Monitors the progress

- Script 3: deploy_OM_BackupDB.bash - Deploy the OM Backing DBs
	- Completes the Backup setup for OM
	- Monitors the progress until the pods are ready

- Script 4: deploy_ProdDB.bash -  Deploy a Production DB
	- Deploy a secure 3 node replica set (with TLS and Auth)
	- Note: use a down-rev verions to show automation later on
	- Monitors the progress until the replica set is ready
	
### Step 3. Login to OM
- login to OM at localhost:8080 with the credentials from init.conf
