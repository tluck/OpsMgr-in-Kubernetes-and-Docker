# OpsMgr K8s Demo

## In Kubernetes Summary:

- This demo will install into a Kubernetes cluster:
  * Ops Manager v6 
  * its Application DB - aka App DB - a Cluster for OM data
  * a blockstore Cluster for backups
  * an oplog Cluster for continous backups
- 2 Production Clusters
  * a example replica set cluster
  * a example sharded cluster.
  * note: TLS Certs are created using a self-signed CA.
  * queriable backup is available too!
	  

### Step 1. Configure K8s with Docker Desktop
- Preference setup:
	* Kubernetes - Check Enable Kubernetes with Docker or create one in AWS (EKS).
	* Reources/Advanced: 
		* Configure 8 Cores
		* Configure 10.5GB of Memory
		* Configure 2GB of swap
		* Disk Image size (~40GB)
		
- Restart to enable new settings

### Step 2. Launch the Services
the **_launch.bash** script runs several "deploy" scripts for each of the following steps:

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

- Script 3: **deploy_Cluster.bash** 
	- Deploy a Cluster - a few more clusters are created
	- the Oplog and Blockstore ReplicaSet Clusters complete the Backup setup for OM
	- myreplicaset is a "Production" ReplicaSet Cluster and has a splitHorizon configuration for external cluster access
		- connect via ```Misc/connect_external.bash``` script
	- mysharded is a "Production" Sharded Cluster using either NodePort or LoadBalancer for external cluster access
	- Monitors the progress until the pods are ready
	
### Step 3. Login to Ops Manager
- login to OM at 
    use https://opsmanager-svc.mongodb.svc.cluster.local:8443 if using LoadBalancer method for service exposure
    or  
    use https://opsmanager-svc.mongodb.svc.cluster.local:32443 is using NopePort method for service exposure
- the admin user credentials and various other settings are held in ```init.conf```
	- the scripts also create a hostname entry such as:
	```127.0.0.1       opsmanager-svc.mongodb.svc.cluster.local # opsmgr```
	into the ```/etc/hosts``` file

	- Note: if you add the custom TLS certificate authority (certs/ca.crt) to your keystore, this allows seamless unchallenged secure https access

# Ops Manager Demo Environment (in Docker)

GitHub Repo:             https://github.com/tluck/OpsMgrDocker
Docker Image Repo:     https://hub.docker.com/repository/docker/tjluckenbach/mongodb

## In Docker Summary:
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
- Login in to http://localhost:8080 (localhost)
- Provision a cluster on the 3 nodes
