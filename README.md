# OpsMgr K8s Demo

## For Kubernetes Summary:

- This demo will install into a Kubernetes cluster:
  * Ops Manager v5 
  * its app DB
  * a blockstore DB for backups
  * an oplog DB for continous backups
- 2 Production DBs
  * a example replica set cluster
  * a example sharded cluster.
  * TLS Certs are created using a self-signed CA.
  * queriable backup is available too!
	  

### Step 1. Configure K8s with Docker Desktop
- Preference setup:
	* Kubernetes - Check Enable Kubernetes
	* Reources/Advanced: 
		* Configure 8 Cores
		* Configure 10GB of Memory
		* Configure 1GB of swap
		* Disk Image size (~40GB)
		
- Restart to enable new settings

### Step 2. Launch the Services
the **_launch.bash** script has several script for each of these steps:

- Script 1: **deploy_Operator.bash**
	- Setup the OM enviroment
	- Defines the namespace
	- Deploys the MongoDB Enterprise K8s Operator

- Script 2: **deploy_OM.bash**
	- Setup the Ops Manager enviroment
  	- Deploy the OM Resources
  		- OpsManager
  		- AppDB 
  	- Monitors the progress of OM for Readiness

- Script 3: **deploy_Database.bash**
	- Deploy a DB - three more are created
	- Oplog1 and Blockstore1 dbs complete the Backup setup for OM
	- My-replica-set is a "Production" DB and has a splitHorizon configuration for external cluster access
		- connect via ```Misc/connect_external.bash``` script
	- Monitors the progress until the pods are ready

- Script 4: **mail/deploy_SMTP.bash**
	- starts a mail relay to send alerts and user invitations
	
### Step 3. Login to OM
- login to OM at https://localhost:8443 with the admin credentials set in ```init.conf```
- or put:
	```127.0.0.1       opsmanager-svc.mongodb.svc.cluster.local # opsmgr```
	into
	```/etc/hosts```
- and add the custom TLS certificate authority (certs/ca.crt) to your keystore to allow secure https without challenge

Ops Manager Demo Environment (in Docker)

GitHub Repo:             https://github.com/tluck/OpsMgrDocker
Docker Image Repo:     https://hub.docker.com/repository/docker/tjluckenbach/mongodb

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
- Login in to http://opsmgr:8080 (localhost)
- Provision a cluster on the 3 nodes
