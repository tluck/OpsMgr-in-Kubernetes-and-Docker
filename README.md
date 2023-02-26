# OpsMgr K8s Demo

## In Kubernetes Summary:

This demo will install OM and a few MDB Clusters into a Kubernetes cluster.

- Ops Manager v6 is the current version.
  * Application DB - aka App DB - a Cluster for OM data
  * For Backup, 2 Clusters are built: a blockstore Cluster for data and an oplog Cluster for continous backups
- 2 Production Clusters
  * an example replica set cluster.
  * an example sharded cluster.
  * TLS Certs are created using a self-signed CA.
- An openLDAP server is included and configured to support OM users and/or DB users.
- Queriable backup is available too!  

### Step 1. Configure a K8s Cluster
- Setup the K8s cluster and install the needed command tools: kubectl, jq, cfssl.
	* Kubernetes - the demo compatible with RH Openshift, Docker-Desktop, Minikube, AWS EKS, GCP K8S.
	* Minimum resources required: 
		* 8 Cores
		* 11GB Memory (2GB of swap)
		* 50GB Disk 

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
	- The script creates various TLS certificates, mdb users, secrets, and related configmaps. In other words, it deploys a cluster.
	- the _launch script deploys several MDB clusters. 
	- The Oplog and Blockstore ReplicaSet Clusters complete the Backup setup for OM
	- The cluster "myreplicaset" is a "Production" ReplicaSet Cluster and has a splitHorizon configuration for external cluster access
		- connect via ```bin/connect_external.bash``` script
	- The cluster "mysharded" is a "Production" Sharded Cluster using either NodePort or LoadBalancer for external cluster access
	- The monitors the progress until the pods of the cluster are ready before it finishes.
	- Note: for convenience, the k8s cluster node names are used for the external access.
	
### Step 3. Login to Ops Manager
- To login to OM, connect with a browser using the user/password in init.conf.

	- Access of OM depends on wether TLS is used and the port exposure methods.  
	- When TLS is configured, use port 8443 (port 8080 is for a non-secure setup).
   		- If using a LoadBalancer, use: https://opsmanager-svc.mynamespace.svc.cluster.local:8443
   		- Or with NodePort, use: https://opsmanager-svc.mynamespace.svc.cluster.local:32443
   		
- The admin user credentials and various other settings are held in ```init.conf```
	- the scripts also create a hostname entry such as:
	```127.0.0.1       opsmanager-svc.<namespace>.svc.cluster.local # opsmgr```
	into the ```/etc/hosts``` file - which allows external access to OM using the same name as used internally (in the cluster).

	- Note: if you add the custom TLS certificate authority (certs/ca.crt) to your keystore, this allows seamless unchallenged secure https access.
	
### Step 4: LDAP Server (Optional)
- Run ```bin/deploy_ldap.bash``` to create the server
   - This creates an openLDAP server and pre-configures OM for users and groups.
   - There are several DBusers: dbAdmin, User01, User02 (password is Mongodb1)
   - There are several OpsMgr Users: Thomas.Luckenbach
   - There are 3 groups:
    	- dn: cn=dbusers,ou=users,dc=example,dc=org
    	- dn: cn=readers,ou=users,dc=example,dc=org
    	- dn: cn=managers,ou=users,dc=example,dc=org
	- The "manager" group is intended for configuring LDAP for OM users
	- The "dbusers" group is intended for configuring LDAP for DBusers

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
